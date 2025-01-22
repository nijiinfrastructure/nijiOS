module MediaHandler

using HTTP
using JSON3
using URIs
using Base64
using MIMEs
using ..Types
using ..API
using ..APIv2
using ..Retry

export upload_media, get_media

const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/gif"]
const ALLOWED_VIDEO_TYPES = ["video/mp4"]
const MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5MB
const MAX_VIDEO_SIZE = 512 * 1024 * 1024  # 512MB

"""
    upload_media(scraper, file_path)

Uploads a media file.
"""
function upload_media(scraper::Scraper, file_path)
    # Determine MIME type of the file
    mime_type = MIMEs.mime_type(file_path)
    
    # Encode file as Base64
    media_data = open(file_path, "r") do file
        Base64.base64encode(read(file))
    end
    
    response = make_request(
        scraper,
        "POST",
        "https://upload.twitter.com/1.1/media/upload.json",
        ["Content-Type" => "application/json"],
        JSON3.write(Dict(
            "media_data" => media_data,
            "media_type" => mime_type
        ))
    )
    
    return JSON3.read(response.body)
end

"""
    get_media(scraper, media_id)

Retrieves information about a media object.
"""
function get_media(scraper::Scraper, media_id)
    response = make_request(
        scraper,
        "GET",
        "https://upload.twitter.com/1.1/media/upload.json?command=STATUS&media_id=$media_id",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

end # module 