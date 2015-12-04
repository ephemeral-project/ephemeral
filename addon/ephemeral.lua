local _ = ep.localize

BINDING_HEADER_EPHEMERAL = 'Ephemeral'
BINDING_NAME_CONSOLE = _'Display Console'
BINDING_NAME_RELOADUI = _'Reload Interface'

ep.version = 20000

function ep.bootstrapEphemeral()
  ep.bootstrapModules()
end
