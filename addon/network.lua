local ceil = math.ceil
local concat = table.concat
local deferral = ep.deferral
local exception = ep.exception
local exceptional = ep.exceptional
local format = string.format
local freeze = ep.freeze
local invoke = ep.invoke
local iterkeys = ep.iterkeys
local load_component = ep.load_component
local promise = ep.promise
local pseudoid = ep.pseudoid
local satisfy = ep.satisfy
local schedule = ep.schedule
local split = ep.split
local subscribe = ep.subscribe
local thaw = ep.thaw
local unsubscribe = ep.unsubscribe
local _schedule_invocation = ep._schedule_invocation

local channel
local conduit
local conference
local group
local guild
local transport

local _character_name = UnitName('player'):lower()
local _network_version = 1
local _encoded_version = format('%x', _network_version)
local _pending_transmissions = {ep.ring(), ep.ring()}
local _poll_scheduled = false
local _token_equivalents = {['~'] = '$', ['^'] = '#'}
local _uniqid_entropy = 65535

local function uniqid()
  _uniqid_entropy = _uniqid_entropy - 1
  if _uniqid_entropy == 0 then
    _uniqid_entropy = 65535
  end
  return format('%04x', _uniqid_entropy)
end

local function _poll_transmissions()
  local ring, sent, transmissions, trn, packet = 1, 0, _pending_transmissions[1]
  _poll_scheduled = false
  while true do
    trn = transmissions:next()
    if trn then
      if trn.count == 1 then
        packet = trn.packet
        transmissions:remove(trn)
      else
        packet = trn.packets[trn.packet]
        if trn.packet < trn.count then
          trn.packet = trn.packet + 1
        else
          transmissions:remove(trn)
        end
      end
      sent = sent + #packet
      trn.transport._send_packet(trn.peer, packet)
    else
      ring = ring + 1
      transmissions = _pending_transmissions[ring]
      if not (transmissions and transmissions.head) then
        break
      end
    end
    if sent >= 1024 then
      if not _poll_scheduled then
        _poll_scheduled = true
        _schedule_invocation({invocation = _poll_transmissions, delta = GetTime() + 1, simple = true})
      end
      break
    end
  end
end

ep.network = ep.module{
  name = 'ephemeral:network',
  description = '',
  version = _network_version,

  transmissions = _pending_transmissions,

  activate = function(self)
    self._active_subscriptions = {
      subscribe('CHAT_MSG_ADDON', {self._monitor_addon_messages, self}),
      --subscribe('CHAT_MSG_CHANNEL', {self._monitor_channel_messages, self}),
      --subscribe('CHAT_MSG_CHANNEL_LEAVE', {self._monitor_channel_messages, self}),
      --subscribe('CHAT_MSG_CHANNEL_NOTICE', {self._monitor_channel_messages, self}),
      --subscribe('PLAYER_GUILD_UPDATE', {self._monitor_special_channels, self}),
      --subscribe('PARTY_MEMBERS_CHANGED', {self._monitor_special_channels, self}),
      --subscribe('RAID_ROSTER_UPDATE', {self._monitor_special_channels, self}),
    }
  end,

  approve = function(self, peer, interaction, descriptor)
    return true
  end,

  deactivate = function(self)
    for i, subscription in ipairs(self._active_subscriptions) do
      unsubscribe(subscription)
    end
    self._active_subscriptions = nil
  end,

  deploy = function(self)
    if not RegisterAddonMessagePrefix('ephemeral') then
      return
    end
    self:activate()
  end,

  _accept_peer = function(self, peer)
    return true
  end,

  _monitor_addon_messages = function(self, event, prefix, content, distribution, peer)
    peer = peer:lower()
    if prefix == 'ephemeral' and self:_accept_peer(peer) then
      if distribution == 'WHISPER' then
        conduit:receive(peer, content)
      elseif distribution == 'PARTY' or distribution == 'RAID' then
        if channel.group.connected then
          channel.group:receive(peer, content)
        end
      elseif distribution == 'GUILD' then
        if channel.guild.connected then
          channel.guild:receive(peer, content)
        end
      end
    end
  end,

  _monitor_channel_messages = function(self, event, content, peer, a3, a4, a5, a6, a7, a8, name)
    local target = channel.channels[name:lower()]
    if target then
      if target.connected then
        if event == 'CHAT_MSG_CHANNEL' then
          target:receive(peer:lower(), content)
        elseif event == 'CHAT_MSG_CHANNEL_LEAVE' then
          target:dropped(peer:lower())
        elseif event == 'CHAT_MSG_CHANNEL_NOTICE' and content == 'YOU_LEFT' then
          target:left()
        end
      elseif event == 'CHAT_MSG_CHANNEL_NOTICE' and content == 'YOU_JOINED' then
        target:_connect_succeeded()
      end
    end
  end,

  _monitor_special_channels = function(self, event)
    if event == 'PLAYER_GUILD_UPDATE' then
      channel.guild:synchronize()
    else
      channel.group:synchronize()
    end
  end
}

transport = ep.prototype('ep.transport', {
  receptions = {},

  receive = function(cls, peer, text)
    if text:sub(2, 2) ~= _encoded_version then
      -- notify user new version exists
      return
    end

    local token, broadcast = text:sub(1, 1), false
    if token == '~' or token == '^' then
      token, broadcast = _token_equivalents[token], true
    end

    local signature, receiver, serial, count, reception, content
    if token == '$' or token == '#' then
      if not broadcast and peer == _character_name then
        return
      end
      signature = text:sub(3, 10)
      receiver = cls:_filter_reception(peer, signature)
      if receiver then
        if token == '$' then
          receiver:_propagate_reception(peer, signature, text:sub(11))
        else
          serial, count = peer..text:sub(11, 14), tonumber(text:sub(15, 18), 16)
          cls.receptions[serial] = {
            content = {text:sub(25)},
            count = count,
            length = tonumber(text:sub(19, 24), 16),
            n = 0,
            peer = peer,
            receiver = receiver,
            serial = serial,
            signature = signature,
            timeout = GetTime() + (ceil(count / 20) * 8)
          }
        end
      end
    elseif token == '=' or token == '!' then
      serial = peer..text:sub(3, 6)
      reception = cls.receptions[serial]
      if reception then
        if token == '=' then
          reception.content[#reception.content + 1] = text:sub(7)
          reception.n = reception.n + 1
        else
          content = concat(reception.content, '')..text:sub(7)
          if #content ~= reception.length then
            content = nil
          end
          reception.receiver:_propagate_reception(peer, reception.signature, content)
          cls.receptions[serial] = nil
        end
      end
    end
  end,

  --[[
    send() algorithm notes
    SendAddonMessage() allows a maximum of 250 characters in a message

    - a single ephemeral message consists of the broadcast flag ('^' or '~'), the token '$', an 8-char signature,
      and the content of the message, not to exceed 240 chars
    - a compound ephemeral message consists of:
        - an initial message, consisting of the broadcast flag ('^' or '~'), the token '#', an 8-char signature,
          a 4-char serial, a 4-char hexadecimal value indicating the total number of chunks,
          a 6-char hexadecimal value indicating the total length of the content, and the first
          226 characters of the content
        - zero or more intermediate messages, consisting of the broadcast flag, the token '=', the same 4-char
          serial as the initial message, and 244 characters of the content
        - a final message, consisting of the broadcast flag, the token '!', the same 4-char serial, and the
          remaining characters of the content

    1. we first check to see if we can send the specified content in a single message, by seeing if its length
       is equal to or less then 240 (since the header of a single message is 10 characters long); if so, we
       associate the single packet and move on
    2. otherwise, we identify the total number of packets required for this message, by adding 18 to its length,
       dividing by 244, and rounding up. each packet in a compound message shares a similar 6-char header, with
       the header of the initial message having an additional 18 characters, hence the math
  ]]

  send = function(self, peer, signature, content, priority, broadcast)
    local length, serial, prefix, trn, packets, pos, idx, span = #content, uniqid()
    trn = {
      content = content,
      count = (length <= 240) and 1 or ceil((length + 18) / 244),
      length = length,
      packet = 1,
      peer = peer,
      priority = priority or 1,
      serial = serial,
      signature = signature,
      transport = self,
    }

    if trn.count == 1 then
      trn.packet = (broadcast and '~' or '$').._encoded_version..signature..content
    else
      packets = {format('%s%s%s%s%04x%06x%s', (broadcast and '^' or '#'), _encoded_version,
          signature, serial, trn.count, length, content:sub(1, 226))}
      pos, idx = 227, 2
      while true do
        span = content:sub(pos, pos + 243)
        if #span == 244 and pos + 244 <= length then
          packets[idx] = '='.._encoded_version..serial..span
          pos = pos + 244
        else
          packets[idx] = '!'.._encoded_version..serial..span
          break
        end
        idx = idx + 1
      end
      trn.packets = packets
    end

    _pending_transmissions[trn.priority]:add(trn)
    if not _poll_scheduled then
      _poll_transmissions()
    end
    return trn
  end,

  _filter_reception = function(cls, peer, signature)
    return cls
  end,

  _propagate_reception = function(self, peer, signature, content)
  end,

  _send_packet = function(peer, content)
    SendAddonMessage('ephemeral', content, 'WHISPER', peer)
  end
})

--[[
  conduit messages:

  connection: "?<component>;<version>;<descriptor>"
    response(unknown-component): "-component;"
    response(version-mismatch): "-version;<version>"
    response(rejected): "-rejected;"
    response(accepted): "+"

  interaction: "#<command>;<data>"

  transmission: "&<data>"

  close: "!"
]]

conduit = ep.prototype('ep.conduit', transport, {
  conduits = {},
  timeout = 4,
  version = 1,

  initialize = function(self, peer, descriptor, signature, connected)
    self.component = self.__name
    self.connected = connected
    self.descriptor = freeze(descriptor)
    self.peer = peer:lower()
    self.signature = signature or pseudoid()
    self.id = self.peer..':'..self.signature

    self.conduits[self.id] = self
    if not connected then
      self:connect()
    end
  end,

  accept = function(cls, peer, signature, component, version, descriptor)
    component = load_component('ep.conduit', component)
    if exceptional(component) then
      cls:send(peer, signature, '-component;')
      return
    end

    version = tonumber(version)
    if version ~= component.version then
      cls:send(peer, signature, format('-version;%d', component.version))
      return
    end

    descriptor = thaw(descriptor)
    if not ep.network:approve(peer, component, descriptor) then
      cls:send(peer, signature, '-rejected;')
      return
    end

    component(peer, descriptor, signature, true)
    cls:send(peer, signature, '+')
  end,

  close = function(self, received)
    if self.connected then
      self.connected = false
      if not received then
        self:send(self.peer, self.signature, '!')
      end
      self.conduits[self.id] = nil
    end
  end,

  connect = function(self)
    if not (self.connected or self.connecting) then
      self.connecting = true
      self:send(self.peer, self.signature, format('?%s;%d;%s', self.component, self.version, self.descriptor))
      schedule({self._connect_failed, self}, self.timeout, 1)
    end
  end,

  interact = function(self, command, data, priority)
    if self.connected then
      self:send(self.peer, self.signature, '#'..command..';'..freeze(data), priority)
    end
  end,

  onconnect = function(self, invocation)
    if self.connected then
      invoke(invocation, self)
    elseif self.connecting then
      promise(self, 'onconnect', invocation)
    else
      invoke(invocation, exception('ConduitNotConnecting'))
    end
  end,

  received = function(self, data)
  end,

  transmit = function(self, data, priority)
    if self.connected then
      self:send(self.peer, self.signature, '&'..data, priority)
      return true
    else
      return false
    end
  end,

  _connect_failed = function(self, exc)
    if self.connecting and not self.connected then
      self.connected, self.connecting = nil, nil
      if not exc then
        exc = exception('ConduitTimedOut')
      end
      satisfy(self, 'onconnect', exc)
    end
  end,

  _connect_succeeded = function(self)
    if self.connecting and not self.connected then
      self.connected, self.connecting = true, nil
      satisfy(self, 'onconnect', self)
    end
  end,

  _filter_reception = function(cls, peer, signature)
    return cls.conduits[peer..':'..signature] or cls
  end,

  _propagate_reception = function(self, peer, signature, content)
    local token = content:sub(1, 1)
    if token == '?' or token == '@' then
      self:accept(peer, signature, split(content:sub(2), ';', 2))
    elseif token == '+' then
      self:_connect_succeeded()
    elseif token == '-' then
      local cause, version = split(content:sub(2), ';', 1)
      -- FIX
      self:_connect_failed(exception(cause))
    elseif token == '&' then
      self:received(content:sub(2))
    elseif token == '#' then
      local command, data = split(content:sub(2), ';', 1)
      command = self[command..'_received']
      if command then
        command(self, thaw(data))
      end
    elseif token == '!' then
      self:close(true)
    end
  end,

  _send_packet = function(peer, content)
    SendAddonMessage('ephemeral', content, 'WHISPER', peer)
  end
})

channel = ep.prototype('ep.channel', transport, {
  channels = {},

  initialize = function(self, name)
    self.conferences = {}
    self.connected = false
    self.name = name

    self.id = GetChannelName(name)
    if self.id >= 1 then
      self:_connect_succeeded()
    else
      self:connect()
    end
    self.channels[name] = self
  end,

  instantiate = function(self, name)
    return self.channels[name]
  end,

  close = function(self, signature)
    local conference = self.conferences[signature]
    if conference then
      conference:shutdown()
      if self.connected then
        self:send(self.name, signature, '-')
      end
      self.conferences[signature] = nil
    end
  end,

  connect = function(self)
    if not (self.connected or self.connecting) then
      self.connecting = true
      if JoinPermanentChannel(self.name, nil, nil, 0) then
        self.id = GetChannelName(name)
      else
        self:_connect_failed()
      end
    end
  end,

  dropped = function(self, peer)
    for signature, conference in pairs(self.conferences) do
      if conference.participants[peer] then
        conference:left(conference.participants[peer], true)
        conference.participants[peer] = nil
      end
    end
  end,

  hide = function(self)
    for i = 1, NUM_CHAT_WINDOWS do
      ChatFrame_RemoveChannel(_G['ChatFrame'..i], self.name)
    end
  end,

  initiate = function(self)
  end,

  left = function(self)
    self.connected, self.id = false, nil
    for signature in iterkeys(self.conferences) do
      self.conferences[signature]:shutdown()
      self.conferences[signature] = nil
    end
    schedule({self.connect, self}, 1, 1, false)
  end,

  onconnect = function(self, invocation)
    if self.connected then
      invoke(invocation, self)
    elseif self.connecting then
      promise(self, 'onconnect', invocation)
    else
      invoke(invocation, exception('ChannelNotConnecting'))
    end
  end,

  shutdown = function(self)
    if self.connected then
      self.connected = false
      for signature in iterkeys(self.conferences) do
        self.conferences[signature]:shutdown()
        self.conferences[signature] = nil
      end
      if self.name:sub(1, 1) ~= '$' then
        self.id = nil
        if GetChannelName(self.name) > 0 then
          LeaveChannelByName(self.name)
        end
        self.channels[self.name] = nil
      end
    end
  end,

  _connect_failed = function(self, exc)
    if self.connecting and not self.connected then
      self.connected, self.connecting = false, nil
      if not ext then
        exc = exception('ChannelConnectFailed')
      end
      satisfy(self, 'onconnect', exc)
    end
  end,

  _connect_succeeded = function(self)
    if not self.connected then
      self.connected, self.connecting = true, nil
      self:hide()
      satisfy(self, 'onconnect', self)
    end
  end,

  _filter_reception = function(self, peer, signature)
    if self.conferences[signature] then
      return self
    end
  end,

  _propagate_reception = function(self, peer, signature, content)
    local conference, token, participant, descriptor = self.conferences[signature], content:sub(1, 1)
    participant = conference.participants[peer]
    if token == '@' then
      descriptor = thaw(content:sub(2))
      if participant then
        participant.descriptor = descriptor
      else
        participant = {name = peer, descriptor = descriptor}
        conference.participants[peer] = participant
      end
      self:send(self.name, signature, '+'..conference.descriptor, nil, true)
      conference:acknowledged(participant)
    elseif token == '+' then
      if not participant then
        participant = {name = peer, descriptor = thaw(content:sub(2))}
        conference.participants[peer] = participant
        conference:acknowledged(participant)
      end
    elseif token == '=' then
      descriptor = thaw(content:sub(2))
      if participant then
        participant.descriptor = descriptor
      else
        participant = {name = peer, descriptor = descriptor}
        conference.participants[peer] = participant
      end
      conference:updated(participant)
    elseif token == '-' then
      if participant then
        conference:left(participant)
        confernece.participants[peer] = nil
      end
    elseif token == '#' then
      if participant then
        local command, data = split(content:sub(2), ';', 1)
        command = conference[command..'_received']
        if command then
          command(conference, participant, thaw(data))
        end
      end
    elseif token == '&' then
      if participant then
        conference:received(participant, content:sub(2))
      end
    end
  end,

  _send_packet = function(peer, content)
    SendChatMessage(content, 'CHANNEL', nil, GetChannelName(peer))
  end
})

conference = ep.prototype('ep.conference', {
  initialize = function(self, channel, descriptor, signature)
    if type(channel) ~= 'table' then
      channel = ep.channel(channel)
    end

    self.channel = channel
    self.component = self.__name
    self.descriptor = freeze(descriptor)
    self.joined = false
    self.signature = signature or pseudoid()

    channel.conferences[self.signature] = self
    channel.onconnect({self.join, self})
  end,

  instantiate = function(self, channel, descriptor, signature)
    if type(channel) ~= 'table' then
      channel = ep.channel.channels[channel]
    end
    if channel then
      return channel.conferences[signature]
    end
  end,

  join = function(self, channel)
    if exceptional(channel) then
      satisfy(self, 'onjoin', channel)
    elseif not (self.joined or self.joining) then
      self.joining = true
      self:send('@'..self.descriptor, nil, true)
    end
  end,

  send = function(self, content, priority, broadcast)
    self.channel:send(self.channel.name, self.signature, content, priority, broadcast)
  end
})

group = ep.prototype('ep.network.group', channel, {
  initialize = function(self)
    self.conferences = {}
    self.connected = false
    self.name = '$group'

    self:synchronize()
    self.channels['$group'] = self
  end,

  synchronize = function(self)
    if GetNumGroupMembers() > 0 then
      self.connected = true
    else
      self:shutdown()
    end
  end,

  _send_packet = function(peer, content)
    SendAddonMessage('ephemeral', content, 'RAID')
  end
})

guild = ep.prototype('ep.network.guild', channel, {
  initialize = function(self)
    self.conferences = {}
    self.connected = false
    self.name = '$guild'

    self:synchronize()
    self.channels['$guild'] = self
  end,

  synchronize = function(self)
    if IsInGuild() then
      self.connected = true
    else
      self:shutdown()
    end
  end,

  _send_packet = function(peer, content)
    SendAddonMessage('ephemeral', content, 'GUILD')
  end
})

channel.group = group()
channel.guild = guild()

ep.channel = channel
ep.conduit = conduit
ep.conference = conference
ep.transport = transport



ep.testconduit = ep.prototype('ep.testconduit', conduit, {
  version = 1,

  test_received = function(self, data)
    _dump_to_shell(ep.repr(data))
  end
})
