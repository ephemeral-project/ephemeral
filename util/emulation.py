import curses
import logging
import os
import shlex
import socket as sock
import time
import traceback
from collections import deque
from datetime import datetime
from glob import glob
from os import path
from Queue import Queue
from thread import start_new_thread
from threading import Lock

from lupa import LuaRuntime

log = logging.getLogger()
log.setLevel(logging.DEBUG)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter('%(asctime)s %(name)s %(levelname)s %(message)s'))
log.addHandler(handler)

class ConnectionClosed(Exception):
    pass

class Shell(object):
    def __init__(self, runtime, socket):
        self.buffer = ''
        self.runtime = runtime
        self.socket = socket
        start_new_thread(self.run, ())
    
    def bind(self, emulator):
        self.emulator = emulator
        emulator.shell = self
        self.socket.send('connected to %r\n\n' % emulator)

    def notify(self, text):
        self.socket.send('!!%s\n\n' % text)

    def pull(self):
        while True:
            if '\n\n' in self.buffer:
                data, _, self.buffer = self.buffer.partition('\n\n')
                return data
            receipt = self.socket.recv(4096)
            if receipt:
                self.buffer += receipt
            else:
                raise ConnectionClosed()

    def run(self):
        try:
            name = self.pull()
            if name in self.runtime.emulators:
                self.bind(self.runtime.emulators[name])
            while True:
                data = self.pull()
                if data:
                    try:
                        result = self.emulator.lua.execute('return sn.repr(sn.interpret([[%s]]))' % data)
                    except Exception, exc:
                        self.socket.send(repr(exc).rstrip() + '\n\n')
                    else:
                        if result:
                            self.socket.send(str(result).rstrip() + '\n\n')
        except ConnectionClosed:
            return

def shell_connection(path, emulator):
    lock = Lock()
    socket = sock.socket(sock.AF_UNIX, sock.SOCK_STREAM)
    socket.connect(path)
    socket.send(emulator + '\n\n')

    def pull(buffer, show):
        while True:
            if '\n\n' in buffer:
                data, _, buffer = buffer.partition('\n\n')
                return data, buffer
            receipt = socket.recv(4096)
            if receipt:
                buffer += receipt
            else:
                raise ConnectionClosed()

    def listen(show):
        buffer = ''
        while True:
            data, buffer = pull(buffer, show)
            if data:
                show(data)

    try:
        window = curses.initscr()
        curses.start_color()
        window.idlok(1)
        window.scrollok(True)
        height, width = window.getmaxyx()
        window.setscrreg(1, height - 2)

        def show(text):
            with lock:
                for line in text.strip().split('\n'):
                    window.scroll()
                    window.addstr(height - 3, 0, line)
                window.move(height - 1, 0)
                window.refresh()

        start_new_thread(listen, (show,))
        while True:
            line = window.getstr(height - 1, 0)
            window.hline(height - 1, 0, ' ', width)
            if line == '\q':
                break
            show('>> ' + line)
            socket.send(line + '\n\n')
    except ConnectionClosed:
        pass
    finally:
        curses.endwin()

class AddonEnumerator(object):
    def __init__(self, basepath):
        self.basepath = basepath

    def __iter__(self):
        try:
            addons = self.addons
        except AttributeError:
            addons = self.enumerate()
        for addon in addons:
            yield addon

    def enumerate(self):
        self.addons = []
        for entry in glob(path.join(self.basepath, '*')):
            if path.isdir(entry):
                candidates = glob(path.join(entry, '*.toc-emulated'))
                if not candidates:
                    candidates = glob(path.join(entry, '*.toc'))
                if candidates and len(candidates) == 1:
                    with open(candidates[0]) as openfile:
                        addon = self.parse(openfile.read())
                    addon.update(name=path.basename(entry), path=entry)
                    self.addons.append(addon)
        else:
            return self.addons

    def parse(self, source):
        addon = {'tags': {}, 'files': []}
        for line in source.strip().split('\n'):
            line = line.strip()
            if line.startswith('##'):
                tag, value = line[2:].strip().split(':', 1)
                addon['tags'][tag.strip()] = value.strip()
            elif line and not line.startswith('#'):
                addon['files'].append(line)
        else:
            return addon

class Character(object):
    def __init__(self, name, guild=None, **params):
        self.cls = params.get('cls', 'warrior')
        self.faction = params.get('faction', 'alliance')
        self.gender = params.get('gender', 'male')
        self.guild = guild
        self.name = name
        self.race = params.get('race', 'human')

        self.guid = name.lower()
        if len(self.guid) < 8:
            self.guid += '0' * (8 - len(self.guid))

    def __repr__(self):
        return 'Character(%r)' % self.name

class Channel(object):
    def __init__(self, runtime, type, name):
        self.members = set()
        self.name = name
        self.runtime = runtime
        self.type = type

    def __len__(self):
        return len(self.members)

    def leave(self, member):
        if member not in self.members:
            return

        self.members.remove(member)
        args = (None, member.name, None, None, None, None, None, None, self.name)

    def send_message(self, author, message, language=None):
        args = (message, author, language, None, None, None, None, None, self.name)
        for member in self.members:
            member.queue_event('CHAT_MSG_CHANNEL', args)

ExposedFunctions = []
def exposed(function):
    ExposedFunctions.append(function.__name__)
    return function

class Emulator(object):
    def __init__(self, runtime, character, enabled_addons=None):
        self.addons = []
        self.character = character
        self.guild = None
        self.log = logging.getLogger(character.name.lower())
        self.name = character.name.lower()
        self.runtime = runtime
        self.shell = None
        self.status = 'inactive'

        for addon in runtime.addons:
            if not enabled_addons or addon['name'] in enabled_addons:
                self.addons.append(addon.copy())

        runtime.emulators[self.name] = self

    def __repr__(self):
        return 'Emulator(%r, %r)' % (self.name, self.status)

    @property
    def active(self):
        return self.status == 'active'

    def call_onevent(self, event, args):
        self.log.info('%s: %r', event, args)
        if self.shell:
            self.shell.notify('%s: %r' % (event, args))

        handler = self.scripts.get('OnEvent')
        if handler and event in self.events:
            return handler(event, *args)

    def call_onupdate(self):
        handler = self.scripts.get('OnUpdate')
        if handler:
            tick = time.time()
            if self.tick:
                handler(None, tick - self.tick)
            else:
                handler(None, 0.0)
            self.tick = tick

    def queue_event(self, event, args):
        self.queue.append((event, args))
    
    def restart(self):
        if self.active:
            self.shutdown()
        self.startup()

    def run(self):
        queue = self.queue
        while queue:
            self.call_onevent(*queue.popleft())
        self.call_onupdate()

    def shutdown(self):
        self.log.info('shutting down emulator')
        self.call_onevent('PLAYER_LOGOUT', [])

        self.status = 'inactive'
        self.runtime.deactivate(self)
        self.log.info('emulator shutdown complete')

    def startup(self):
        self.log.info('starting up emulator')
        self.channels = [None]
        self.dump = Queue()
        self.events = set()
        self.party = None
        self.queue = deque()
        self.scripts = {}
        self.tick = 0

        self.lua = LuaRuntime()
        self.globals = self.lua.globals()
        for name in ExposedFunctions:
            self.globals[name] = getattr(self, name)
        self.lua.execute(emulation_package)

        for addon in self.addons:
            load_on_demand = addon['tags'].get('LoadOnDemand')
            if not load_on_demand:
                self._load_addon(addon)

        handler = self.scripts.get('OnLoad')
        if handler:
            handler(None)

        self.call_onevent('PLAYER_LOGIN', [])
        self.call_onevent('PLAYER_ENTERING_WORLD', [])
        self.status = 'active'
        self.runtime.activate(self)
        self.log.info('emulator startup complete')

    def _get_addon(self, id):
        if isinstance(id, dict):
            return id
        elif isinstance(id, basestring):
            for addon in self.addons:
                if addon['name'] == id:
                    return addon
        try:
            return self.addons[id - 1]
        except IndexError:
            return

    @exposed
    def GetAddOnMetadata(self, id, field):
        addon = self._get_addon(id)
        if addon:
            return addon['tags'].get(field)

    @exposed
    def GetNumAddOns(self):
        return len(self.addons)

    @exposed
    def GetNumPartyMembers(self):
        party = self.party
        if party and party.type == 'party':
            return len(party)
        else:
            return 0

    @exposed
    def GetNumRaidMembers(self):
        raid = self.party
        if raid and raid.type == 'raid':
            return len(raid)
        else:
            return 0

    @exposed
    def GetRealmName(self):
        return self.runtime.realm

    @exposed
    def GetTime(self):
        return time.time()

    @exposed
    def IsAddOnLoaded(self, id):
        addon = self._get_addon(id)
        return (addon and addon.get('loaded'))

    @exposed
    def IsInGuild(self):
        return bool(self.guild)

    @exposed
    def JoinPermanentChannel(self, name, password=None, frameId=None, enable_voice=False):
        channel = self.runtime.get_channel(name)

    @exposed
    def LeaveChannelByName(self, name):
        pass

    @exposed
    def RegisterAddonMessagePrefix(self, prefix):
        return True

    @exposed
    def SendAddonMessage(self, prefix, text, type, target=None):
        self.runtime.send_addon_message(self, prefix, text, type, target)

    @exposed
    def _dump(self, *args):
        self.dump.put(args)

    @exposed
    def _dump_to_shell(self, content):
        if self.shell:
            self.shell.notify(content)

    @exposed
    def _get_addon_info(self, id):
        addon = self._get_addon(id)
        if addon:
            return [addon['name'], addon['tags'].get('Title'), addon['tags'].get('Notes'), True,
                (addon['tags'].get('LoadOnDemand') or addon.get('loaded'))]

    @exposed
    def _get_character(self, field=None):
        return (getattr(self.character, field) if field else self.character)

    @exposed
    def _get_channel_name(self, id):
        try:
            id = int(id)
        except ValueError:
            for i, channel in enumerate(self.channels[1:]):
                if channel.name.lower() == id.lower():
                    return [i, channel.name]
            else:
                return [0, None]
        else:
            if id in self.channels:
                return [id, self.channels[id].name]
            else:
                return [0, None]

    @exposed
    def _get_current_date(self):
        return datetime.now()

    @exposed
    def _is_event_registered(self, event):
        self.log.debug('_is_event_registered(%r)', event)
        return event in self.events

    @exposed
    def _load_addon(self, id):
        addon = self._get_addon(id)
        if not addon:
            return
        if addon.get('loaded'):
            return True

        default_path = self.globals.package.path
        self.globals.package.path = '%s/?.lua;%s' % (addon['path'], default_path)

        self.log.info("attempting to load addon '%s'", addon['name'])
        for filename in addon['files']:
            if filename.endswith('.lua'):
                self.log.info("attempting to inject lua file '%s/%s'", addon['name'], filename)
                self.lua.require(filename[:-4])

        # load saved variables here

        self.call_onevent('ADDON_LOADED', [addon['name']])

        self.globals.package.path = default_path
        addon['loaded'] = True

    @exposed
    def _send_addon_message(self, prefix, content, channel):
        pass

    @exposed
    def _set_script(self, script, func):
        self.log.debug('_set_script(%r, %r)', script, func)
        if func:
            self.scripts[script] = func
        elif script in self.scripts:
            del self.scripts[script]

    @exposed
    def _toggle_event(self, event, receiving):
        if receiving:
            self.events.add(event)
        else:
            self.events.discard(event)

class Command(object):
    log = logging.getLogger('command')
    def __init__(self, runtime, command):
        command, sep, args = command.strip().partition(' ')
        self.args = []
        self.command = command
        self.runtime = runtime
        if args:
            self.args = shlex.split(args)

    def __call__(self):
        try:
            method = getattr(self, self.command)
        except AttributeError:
            self.log.error("invalid command '%s'", self.command)
            return
        try:
            method(self.runtime, *self.args)
        except Exception:
            self.log.exception("command '%s' raised exception", self.command)

    def lua(self, runtime, name, source):
        emulator = self._get_emulator(name)
        if emulator:
            self.log.info("evaling '%s' on emulator '%s'", source, name)
            try:
                emulator.lua.execute(source)
            except Exception:
                self.log.exception("evaling '%s' raised an exception", source)

    def restart(self, runtime, name):
        emulator = self._get_emulator(name)
        if emulator:
            emulator.restart()

    def run_lua(self, runtime, name, filename):
        emulator = self._get_emulator(name)
        if emulator:
            self.log.info("running '%s' on emulator '%s'", filename, name)
            try:
                with open(filename) as openfile:
                    emulator.lua.execute(openfile.read())
            except Exception:
                self.log.exception("running '%s' raised an exception", filename)

    def run_python(self, runtime, filename):
        self.log.info("running '%s'", filename)
        with open(filename) as openfile:
            try:
                exec openfile
            except Exception:
                self.log.exception("running '%s' raised an exception", filename)

    def _get_emulator(self, name, active=True):
        emulator = self.runtime.emulators.get(name)
        if not emulator:
            self.log.error("emulator '%s' does not exist", name)
            return
        if active and not emulator.active:
            self.log.error("emulator '%s' is not active", name)
            return
        return emulator

class Runtime(object):
    def __init__(self, path, fps=32, realm='Realm', fifo='/tmp/wow.fifo'):
        self.active_emulators = set()
        self.addons = AddonEnumerator(path)
        self.channels = {}
        self.commands = deque()
        self.emulators = {}
        self.fifo = fifo
        self.fps = fps
        self.log = logging.getLogger('runtime')
        self.realm = realm
        self.running = False

    def activate(self, emulator):
        self.active_emulators.add(emulator)

    def deactivate(self, emulator):
        self.active_emulators.remove(emulator)

    def get_channel(self, name):
        name = name.lower()
        if name in self.channels:
            return self.channels[name]
        channel = self.channels[name] = Channel(self, 'channel', name)
        return channel

    def listen(self):
        if not path.exists(self.fifo):
            os.mkfifo(self.fifo)

        while True:
            fd = os.open(self.fifo, os.O_RDONLY)
            command = os.read(fd, 2048).strip()
            os.close(fd)
            if command.lower() == 'stop':
                self.stop()
                return
            else:
                Command(self, command)()

    
    def listen_for_shells(self):
        try:
            os.remove(self.socket_path)
        except:
            pass

        socket = sock.socket(sock.AF_UNIX, sock.SOCK_STREAM)
        socket.bind(self.socket_path)
        socket.listen(50)
        while True:
            try:
                instance, address = socket.accept()
            except sock.error:
                continue
            else:
                Shell(self, instance)

    def run(self):
        if self.fifo:
            start_new_thread(self.listen, ())

        self.socket_path = '/tmp/wow.sock'
        start_new_thread(self.listen_for_shells, ())

        active_emulators = self.active_emulators
        interval = 1.0/self.fps

        self.running = True
        while self.running:
            time.sleep(interval)
            for emulator in active_emulators:
                emulator.run()

    def send_addon_message(self, emulator, prefix, text, type, target):
        #self.log.debug('send_add_message(%r, %r, %r, %r, %r)', emulator, prefix, text, type, target)
        if type == 'WHISPER':
            target = self.emulators.get(target.lower())
            if target and target.active:
                target.queue_event('CHAT_MSG_ADDON', (prefix, text, 'WHISPER', emulator.name))
            else:
                emulator.queue_event('CHAT_MSG_SYSTEM', ())

    def send_chat_message(self, emulator, msg, type, language, channel):
        if type == 'WHISPER':
            target = self.emulators.get(target.lower())
            if target and target.active:
                target.queue_event('CHAT_MSG_WHISPER', (msg, emulator.name))
            else:
                emulator.queue_event('CHAT_MSG_SYSTEM', ())

    def stop(self):
        self.running = False

emulation_package = """
__emulating__ = true

date = os.date
time = os.time

EventBridge = {
    IsEventRegistered = function(self, event)
        return _is_event_registered(event)
    end,
    RegisterEvent = function(self, event)
        _toggle_event(event, true)
    end,
    SetScript = function(self, event, func)
        _set_script(event, func)
    end,
    UnregisterEvent = function(self, event)
        _toggle_event(event, false)
    end
}

function CalendarGetDate()
    local now = _get_current_date()
    return now.weekday(), now.month, now.day, now.year
end

function ChatFrame_RemoveChannel(i, name)
end

function GetAddOnInfo(idx)
    local addon = _get_addon_info(idx)
    return addon[0], addon[1] or nil, addon[2] or nil, addon[3], addon[4]
end

function GetBindingKey(key)
    return '/'
end

function GetChannelName(id)
    result = _get_channel_name(id)
    return result[0], result[1]
end

function GetGameTime()
    local now = _get_current_date()
    return now.hour, now.minute
end

function GetGuildInfo(unit)
    if unit == 'player' then
        return nil, nil, nil
    end
end

function SendChatMessage(content, channel, _, _)

end

function UnitClass(unit)
    local class
    if unit == 'player' then
        class = _get_character('cls')
        return class:sub(1, 1):upper()..class:sub(2), class:upper()
    end
end

function UnitFactionGroup(unit)
    local faction
    if unit == 'player' then
        faction = _get_character('faction')
        return faction:sub(1, 1):upper()..faction:sub(2), faction:upper()
    end
end

function UnitGUID(unit)
    if unit == 'player' then
        return _get_character('guid')
    end
end

function UnitName(unit)
    if unit == 'player' then
        return _get_character('name'), nil
    end
end

function UnitRace(unit)
    local race
    if unit == 'player' then
        race = _get_character('race')
        return race:sub(1, 1):upper()..race:sub(2), race:upper()
    end
end

function UnitSex(unit)
    local codes = {unknown=1, male=2, female=3}
    if unit == 'player' then
        return codes[_get_character('gender')]
    end
end
"""

characters = {
    'alpha': Character('alpha'),
    'beta': Character('beta'),
    'gamma': Character('gamma'),
    'delta': Character('delta'),
}
