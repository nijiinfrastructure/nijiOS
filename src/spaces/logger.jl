module TwitterSpacesLogger

"""
    Logger

A simple logger class for debug and info messages.
"""
mutable struct Logger
    debug_enabled::Bool

    function Logger(debug_enabled::Bool=false)
        new(debug_enabled)
    end
end

"""
    info(logger::Logger, msg::String, args...)

Logs an info message with optional arguments.
"""
function info(logger::Logger, msg::String, args...)
    println(stdout, msg, args...)
end

"""
    debug(logger::Logger, msg::String, args...)

Logs a debug message if debug_enabled=true.
"""
function debug(logger::Logger, msg::String, args...)
    if logger.debug_enabled
        println(stdout, msg, args...)
    end
end

"""
    warn(logger::Logger, msg::String, args...)

Logs a warning message.
"""
function warn(logger::Logger, msg::String, args...)
    println(stderr, "[WARN] ", msg, args...)
end

"""
    error(logger::Logger, msg::String, args...)

Logs an error message.
"""
function error(logger::Logger, msg::String, args...)
    println(stderr, msg, args...)
end

"""
    is_debug_enabled(logger::Logger)::Bool

Returns whether debug logging is enabled.
"""
function is_debug_enabled(logger::Logger)::Bool
    return logger.debug_enabled
end

export Logger, info, debug, warn, error, is_debug_enabled

end # module 