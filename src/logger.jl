module Logger

using Logging

export setup_logging

"""
    setup_logging(level::Logging.LogLevel)

Sets up the global logger with the specified log level.
"""
function setup_logging(level::Logging.LogLevel)
    global_logger(SimpleLogger(stderr, level))
end

end # module 