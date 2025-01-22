"""
login the user
"""
function login!(auth::TwitterUserAuth, username::String, password::String, email::Union{String,Nothing}=nothing)
    # Guest Token updat if needed
    if isnothing(auth.guest_token) || 
       isnothing(auth.guest_created_at) || 
       now() - auth.guest_created_at > Minute(30)
        update_guest_token!(auth)
    end
    
    # init login flow
    flow = init_login_flow(auth)
    
    # makes login flow
    while !isnothing(flow.subtask)
        subtask_id = get(flow.subtask, "subtask_id", "")
        
        if subtask_id == "LoginJsInstrumentationSubtask"
            flow = handle_js_instrumentation(auth, flow)
        elseif subtask_id == "LoginEnterUserIdentifierSSO"
            flow = handle_username(auth, flow, username)
        elseif subtask_id == "LoginEnterPassword"
            flow = handle_password(auth, flow, password)
        elseif subtask_id == "LoginAcid"
            if isnothing(email)
                throw(ErrorException("Email verification required but no email provided"))
            end
            flow = handle_email(auth, flow, email)
        else
            throw(ErrorException("Unknown subtask: $subtask_id"))
        end
    end
    
    return auth
end

# Helper Function for login
function update_guest_token!(auth::TwitterUserAuth)
    response = HTTP.post(
        "https://api.twitter.com/1.1/guest/activate.json",
        ["Authorization" => "Bearer $(auth.bearer_token)"]
    )
    
    result = JSON3.read(response.body)
    auth.guest_token = result["guest_token"]
    auth.guest_created_at = now()
end

function init_login_flow(auth::TwitterUserAuth)
    data = Dict(
        "flow_name" => "login",
        "input_flow_data" => Dict(
            "flow_context" => Dict(
                "debug_overrides" => {},
                "start_location" => Dict(
                    "location" => "unknown"
                )
            )
        )
    )
    
    return execute_flow_task(auth, data)
end 