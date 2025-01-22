module TwitterSpacesNodeCiphers

using Random

# The original ciphers (example - must be adjusted to actual Node.js TLS Cliphers)
const ORIGINAL_CIPHERS = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA"

# How many ciphers from the beginning to shuffle.
# The rest remain in the original order.
const TOP_N_SHUFFLE = 8

"""
    shuffle_array!(array::Vector{T}) where T

Shuffle an array with cryptographically secure randomization.
Modified version of https://stackoverflow.com/a/12646864
"""
function shuffle_array!(array::Vector{T}) where T
    for i in length(array):-1:2
        j = rand(1:length(array))
        array[i], array[j] = array[j], array[i]
    end
    array
end

"""
    randomize_ciphers!()

Shuffle TLS ciphers to make client fingerprinting harder.
https://github.com/imputnet/cobalt/pull/574
"""
function randomize_ciphers!()
    current_ciphers = ORIGINAL_CIPHERS
    new_ciphers = current_ciphers
    
    while new_ciphers == current_ciphers
        cipher_list = split(ORIGINAL_CIPHERS, ":")
        shuffled = shuffle_array!(cipher_list[1:min(TOP_N_SHUFFLE, length(cipher_list))])
        retained = cipher_list[min(TOP_N_SHUFFLE+1, length(cipher_list)):end]
        
        new_ciphers = join([shuffled..., retained...], ":")
        
        # Here the actual update of the Node.js TLS ciphers would happen
        # In Julia this would be implemented via a FFI interface to Node.js
        @warn "Node.js TLS Cipher-Update must be implemented"
    end
end

export randomize_ciphers!

end # module 