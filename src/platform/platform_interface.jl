module TwitterSpacesPlatformInterface

"""
    AbstractPlatformExtensions

Interface for platform specific extensions.
"""
abstract type AbstractPlatformExtensions end

"""
    randomize_ciphers!(platform::AbstractPlatformExtensions)

Randomize TLS ciphers to make client fingerprinting harder

**Referenzen:**
- https://github.com/imputnet/cobalt/pull/574
"""
function randomize_ciphers! end

"""
    GenericPlatform

Standard-Implementation of PlatformExtensions.
"""
struct GenericPlatform <: AbstractPlatformExtensions end

# Empty implementation for generic platform
randomize_ciphers!(::GenericPlatform) = nothing

# Singleton-Instance of generic platform
const generic_platform = GenericPlatform()

export AbstractPlatformExtensions, randomize_ciphers!, generic_platform

end # module 