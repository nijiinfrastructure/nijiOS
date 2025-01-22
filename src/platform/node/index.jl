module TwitterSpacesNode

using ..TwitterSpacesPlatformInterface
using ..TwitterSpacesNodeCiphers

"""
    NodePlatform

Node.js-specific implementation of PlatformExtensions.
"""
struct NodePlatform <: AbstractPlatformExtensions end

"""
    randomize_ciphers!(platform::NodePlatform)

Implementation von randomize_ciphers! für Node.js Plattform.
"""
function randomize_ciphers!(::NodePlatform)
    TwitterSpacesNodeCiphers.randomize_ciphers!()
    nothing
end

# Singleton-Instance Node Platform
const platform = NodePlatform()

export platform

end # module 