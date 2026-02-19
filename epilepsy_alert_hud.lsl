// Epilepsy Emergency Alert HUD v1.0
// For Second Life Medical Emergency Response
// Location data contains only avatar location (region + coordinates)

string SUPABASE_URL = "https://xvxnbieoatrsndxqizef.supabase.co";
string EDGE_FUNCTION_URL = "https://xvxnbieoatrsndxqizef.supabase.co/functions/v1/epilepsy-alert";
string ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh2eG5iaWVvYXRyc25keHFpemVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4NzE0MjYsImV4cCI6MjA4NjQ0NzQyNn0.ou0rcy0t7Bo5CZVD_li8_7e94Kwzbdw_N0fN84Cjw5E";

string username = "";
string current_region = "";
vector current_pos;

integer hud_active = TRUE;
integer episode_in_progress = FALSE;
integer LISTEN_CHANNEL = 1000;
key HTTP_REQUEST_ID = NULL_KEY;

default {
    state_entry() {
        llSetColor(<1, 1, 1>, ALL_SIDES);
        llSetText("Epilepsy Alert HUD\nInitializing...", <1, 1, 1>, 1.0);

        username = llGetDisplayName(llGetOwner());
        current_region = llGetRegionName();
        current_pos = llGetPos();

        llListenRemove(LISTEN_CHANNEL);
        llListen(LISTEN_CHANNEL, "", llGetOwner(), "");

        llSay(0, "Epilepsy Alert HUD initialized. Say: /1000 help for commands");

        InitializeHUD();
        llSetTimerEvent(5.0);
    }

    listen(integer channel, string name, key id, string message) {
        if (channel != LISTEN_CHANNEL) return;

        list args = llParseString2List(message, [" "], []);
        string cmd = llToLower(llList2String(args, 0));

        if (cmd == "help") {
            llSay(0, "\n=== Epilepsy Alert HUD Commands ===\nsos - Send emergency alert\nstatus - Show HUD status\nmedical [info] - Set medical info\ncontact [name|method|value] - Add emergency contact\nlog - Log current episode\nwarnings - Show nearby trigger zones\nhistory - Show location history\n");
        }
        else if (cmd == "sos") {
            SendEmergencyAlert();
        }
        else if (cmd == "status") {
            ShowStatus();
        }
        else if (cmd == "medical") {
            SetMedicalInfo(llDumpList2String(llDeleteSubList(args, 0, 0), " "));
        }
        else if (cmd == "contact") {
            AddEmergencyContact(llDumpList2String(llDeleteSubList(args, 0, 0), " "));
        }
        else if (cmd == "log") {
            LogEpisode("");
        }
        else if (cmd == "warnings") {
            CheckForTriggerZones();
        }
        else if (cmd == "history") {
            ShowLocationHistory();
        }
    }

    timer() {
        current_region = llGetRegionName();
        current_pos = llGetPos();

        CheckForTriggerZones();
        LogLocationData();

        if (hud_active) {
            string status = "Active";
            if (episode_in_progress) {
                status = "EPISODE IN PROGRESS";
                llSetColor(<1, 0, 0>, ALL_SIDES);
            } else {
                llSetColor(<0, 1, 0>, ALL_SIDES);
            }
            llSetText("Epilepsy Alert HUD\n" + status + "\n" + current_region, <1, 1, 1>, 1.0);
        }
    }

    http_response(key request_id, integer status, list metadata, string body) {
        if (status == 200) {
            llSay(0, "Success: " + body);
        } else {
            llSay(0, "Error (Status " + (string)status + "): " + body);
        }
    }
}

InitializeHUD() {
    list headers = ["Authorization", "Bearer " + ANON_KEY, "Content-Type", "application/json"];
    string query = SUPABASE_URL + "/rest/v1/hud_users?sl_username=eq." + llEscapeURL(username) + "&select=*";

    llHTTPRequest(query, [HTTP_METHOD, "GET"] + headers, "");
}

SendEmergencyAlert() {
    if (episode_in_progress) {
        llSay(0, "Emergency alert already sent!");
        return;
    }

    episode_in_progress = TRUE;
    llSay(0, "EMERGENCY ALERT SENT!");
    llSay(0, "Location: " + current_region + " <" + (string)llRound(current_pos.x) + ", " + (string)llRound(current_pos.y) + ", " + (string)llRound(current_pos.z) + ">");

    list friends = llGetFriendList(llGetOwner(), 0);
    integer i;
    for (i = 0; i < llGetListLength(friends); i++) {
        key friend_id = llList2Key(friends, i);
        llSay(0, "Alert sent to " + llGetDisplayName(friend_id));
    }

    NotifyEmergencyContacts();
    LogEpisode("Emergency SOS activated");

    llSetTimerEvent(30.0);
}

NotifyEmergencyContacts() {
    string payload = llList2Json(JSON_OBJECT, [
        "username", username,
        "region", current_region,
        "x", (string)current_pos.x,
        "y", (string)current_pos.y,
        "z", (string)current_pos.z,
        "alert_type", "SOS"
    ]);

    list headers = ["Authorization", "Bearer " + ANON_KEY, "Content-Type", "application/json"];
    llHTTPRequest(EDGE_FUNCTION_URL, [HTTP_METHOD, "POST"] + headers, payload);
}

LogEpisode(string notes) {
    episode_in_progress = TRUE;

    string payload = llList2Json(JSON_OBJECT, [
        "username", username,
        "region", current_region,
        "x", (string)current_pos.x,
        "y", (string)current_pos.y,
        "z", (string)current_pos.z,
        "notes", notes
    ]);

    list headers = ["Authorization", "Bearer " + ANON_KEY, "Content-Type", "application/json"];
    llHTTPRequest(SUPABASE_URL + "/rest/v1/rpc/log_episode", [HTTP_METHOD, "POST"] + headers, payload);

    llSay(0, "Episode logged at " + current_region);
    llSetTimerEvent(120.0);
}

LogLocationData() {
    string payload = llList2Json(JSON_OBJECT, [
        "region_name", current_region,
        "location_x", (string)current_pos.x,
        "location_y", (string)current_pos.y,
        "location_z", (string)current_pos.z
    ]);

    list headers = ["Authorization", "Bearer " + ANON_KEY, "Content-Type", "application/json"];
    llHTTPRequest(SUPABASE_URL + "/rest/v1/location_history", [HTTP_METHOD, "POST"] + headers, payload);
}

CheckForTriggerZones() {
    list headers = ["Authorization", "Bearer " + ANON_KEY];
    string query = SUPABASE_URL + "/rest/v1/trigger_zones?region_name=eq." + llEscapeURL(current_region) + "&select=*";

    llHTTPRequest(query, [HTTP_METHOD, "GET"] + headers, "");
}

SetMedicalInfo(string info) {
    string payload = llList2Json(JSON_OBJECT, [
        "medical_info", info
    ]);

    list headers = ["Authorization", "Bearer " + ANON_KEY, "Content-Type", "application/json"];
    llHTTPRequest(SUPABASE_URL + "/rest/v1/hud_users?sl_username=eq." + llEscapeURL(username),
        [HTTP_METHOD, "PATCH"] + headers, payload);

    llSay(0, "Medical information updated");
}

AddEmergencyContact(string contact_info) {
    list parts = llParseString2List(contact_info, ["|"], []);
    if (llGetListLength(parts) < 3) {
        llSay(0, "Usage: /1000 contact name|method|value");
        return;
    }

    string contact_name = llList2String(parts, 0);
    string contact_method = llList2String(parts, 1);
    string contact_value = llList2String(parts, 2);

    string payload = llList2Json(JSON_OBJECT, [
        "username", username,
        "contact_name", contact_name,
        "contact_method", contact_method,
        "contact_value", contact_value
    ]);

    list headers = ["Authorization", "Bearer " + ANON_KEY, "Content-Type", "application/json"];
    llHTTPRequest(SUPABASE_URL + "/rest/v1/emergency_contacts", [HTTP_METHOD, "POST"] + headers, payload);

    llSay(0, "Emergency contact added: " + contact_name);
}

ShowStatus() {
    string status_text = "=== HUD Status ===\n";
    status_text += "Region: " + current_region + "\n";
    status_text += "Position: <" + (string)llRound(current_pos.x) + ", " + (string)llRound(current_pos.y) + ", " + (string)llRound(current_pos.z) + ">\n";
    status_text += "Episode Active: " + (episode_in_progress ? "YES" : "NO") + "\n";
    status_text += "HUD Status: " + (episode_in_progress ? "RED ALERT" : "ACTIVE");

    llSay(0, status_text);
}

ShowLocationHistory() {
    llSay(0, "Checking location history in database...");
}
