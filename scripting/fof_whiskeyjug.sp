#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>

#define PLUGIN_VERSION "1.0.14"
#define CHAT_PREFIX "{skyblue}[Whiskey] "
#define CONSOLE_PREFIX "[Whiskey] "


#define SOUND_JUG       "weapons/whiskey/whiskey_uncork.wav"

#define HUD_X 0.14 //Jug
#define HUD_Y 0.99

new Handle: fof_whiskeyjug_price = INVALID_HANDLE;
new Handle: sm_fof_whiskeyjug_version = INVALID_HANDLE;
new Handle: fof_whiskeyjug = INVALID_HANDLE;
new Handle: hHUDSyncMsg = INVALID_HANDLE;
new bool: bAllowWhiskeyJug = false;
new Float: flWhiskeyJugPrice = 1.0;
new Float: flCashCurrent = 0.0;
new String: szClientName[MAX_NAME_LENGTH];

enum ClientData
{
	UserId,
	bool:hasJug
};

new g_Clients[MAXPLAYERS + 1][ClientData];

public Plugin: myinfo = {
    name = "[FOF] Buy Whiskey Jug Addon",
    author = "Skooma",
    description = "[FOF] Buy Whiskey Jug Addon",
    version = PLUGIN_VERSION,
    url = "https://connorrichlen.me"
};


public OnMapStart() {
    PrecacheSound(SOUND_JUG, true);
    CreateTimer(1.0, Timer_UpdateHUD, .flags = TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnPluginStart() {        
    sm_fof_whiskeyjug_version = CreateConVar("sm_fof_whiskeyjug_version", PLUGIN_VERSION, "[FOF] Buy Whiskey Jug Addon Version", FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD);
    SetConVarString(sm_fof_whiskeyjug_version, PLUGIN_VERSION);
    HookConVarChange(sm_fof_whiskeyjug_version, OnVerConVarChanged);
    HookConVarChange(fof_whiskeyjug_price = CreateConVar("fof_whiskeyjug_price", "50.0", "Sets the purchase price for the Whiskey Jug.", FCVAR_NOTIFY), OnConVarChanged);
    HookConVarChange(fof_whiskeyjug = CreateConVar("fof_whiskeyjug", "1", "Allow (1) or disallow the Whiskey Jug.", FCVAR_NOTIFY, true, 0.0, true, 1.0), OnConVarChanged);

    RegConsoleCmd("sm_whiskey", Command_WhiskeyJug);
    hHUDSyncMsg = CreateHudSynchronizer();

    // Load the clients in g_Clients.
    for (new i = 1; i < MaxClients; ++i)
    {
        if (IsClientInGame(i)) {
            new userid = GetClientUserId(i);
            NewClient(userid, i);
        }
    }
    HookEvent("player_activate", Event_PlayerActivate);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_disconnect", Event_PlayerDisconnect);
    HookEvent("game_newmap", Event_NewMap);
	
}

public OnConfigsExecuted() {
    ScanAllConVars();
}
stock ScanAllConVars() {
    flWhiskeyJugPrice = GetConVarFloat(fof_whiskeyjug_price);
    bAllowWhiskeyJug = GetConVarBool(fof_whiskeyjug);
}
/*
stock int GetWeaponEntityIndexByClassname(int iClient, char[] sWeapon_Classname)
{
    for (int i = 0; i < 4; i++)
    {
        int iWeapon_Entity_Index = GetPlayerWeaponSlot(iClient, i);
        
        if (iWeapon_Entity_Index != -1)
        {
            int iEntity = -1;
            
            while ((iEntity = FindEntityByClassname(iEntity, sWeapon_Classname)) != INVALID_ENT_REFERENCE)
            {
                if (iWeapon_Entity_Index == iEntity)
                    return iEntity;
            }
        }
    }
    
    return -1;
} 
*/
NewClient(userid, client = -1)
{
    if (client == -1)
        client = GetClientOfUserId(userid);
    
    if (g_Clients[client][(ClientData:UserId)] != userid)
    {
        g_Clients[client][(ClientData:UserId)] = userid;
        g_Clients[client][(ClientData:hasJug)] = false;
    }
}

public OnVerConVarChanged(Handle: hConVar, const String: szOldValue[], const String: szNewValue[]){
    if (strcmp(szNewValue, PLUGIN_VERSION, false))
        SetConVarString(hConVar, PLUGIN_VERSION, true, true);
}

public Action: Timer_UpdateHUD(Handle: hTimer, any: iUnused) {
    for (new i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i)) {
            ClearSyncHud(i, hHUDSyncMsg);
            SetHudTextParams(HUD_X, HUD_Y, 1.125, 255, 130, 0, 9, 0, 0.0, 0.0, 0.0);
            
            if ((GetUserFlagBits(i) & ADMFLAG_CUSTOM5) || (GetUserFlagBits(i) & ADMFLAG_ROOT))
            {
                _ShowWhiskeyJugHudText(i, hHUDSyncMsg, "Type !whiskey to buy a Whiskey Jug for $%.0f!", (flWhiskeyJugPrice * 0.5));
            }
            else {
                _ShowWhiskeyJugHudText(i, hHUDSyncMsg, "Type !whiskey to buy a Whiskey Jug for $%.0f!", flWhiskeyJugPrice);
            }
        }
}

public OnConVarChanged(Handle: hConVar, const String: szOldValue[], const String: szNewValue[]){
    ScanAllConVars();
}
public OnClientDisconnect_Post(client) {
    g_Clients[client][(ClientData:hasJug)] = false;
}

public Event_PlayerActivate(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    int userid = GetEventInt(hEvent, "userid");
    int client = GetClientOfUserId(userid);
    g_Clients[client][(ClientData:hasJug)] = false;
    NewClient(userid);
}

public Event_PlayerDisconnect(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	int userid = GetEventInt(hEvent, "userid");
	int client = GetClientOfUserId(userid);
	g_Clients[client][(ClientData:UserId)] = -1;
}

public Event_PlayerDeath(Handle: hEvent, const String: szEventName[], bool: bDontBroadcast) {	
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    g_Clients[client][(ClientData:hasJug)] = false;
    
}

public Event_NewMap(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i < MaxClients; ++i)
	{
		g_Clients[i][(ClientData:hasJug)] = false;
	}
}
stock _ShowWhiskeyJugHudText(iClient, Handle: hHudSynchronizer = INVALID_HANDLE, const String: szFormat[], any: ...)
    if (0 < iClient <= MaxClients && IsClientInGame(iClient)) {

        new String: szBuffer[250];
        VFormat(szBuffer, sizeof(szBuffer), szFormat, 4);

        if (ShowHudText(iClient, -1, szBuffer) < 0 && hHudSynchronizer != INVALID_HANDLE) {
            ShowSyncHudText(iClient, hHudSynchronizer, szBuffer);
        }
}

public Action: Command_WhiskeyJug(int client, int args) {
    if (bAllowWhiskeyJug && flWhiskeyJugPrice != 0.0 && 0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)){
        GetClientName(client, szClientName, sizeof(szClientName));
        flCashCurrent = GetEntPropFloat(client, Prop_Send, "m_flFoFCash");
        new cashCompare;
        if ((GetUserFlagBits(client) & ADMFLAG_CUSTOM5) || (GetUserFlagBits(client) & ADMFLAG_ROOT))
            {
                cashCompare = FloatCompare(flCashCurrent, (flWhiskeyJugPrice * 0.5));
            }
            else {
                cashCompare = FloatCompare(flCashCurrent, flWhiskeyJugPrice);
            }
        if (cashCompare == -1){
            CPrintToChat(client, "%s{red}You're broke! {gold}Get some kills to get some gold, partner!", CHAT_PREFIX );
            return Plugin_Handled;
        }
        else if (g_Clients[client][(ClientData:hasJug)] == true) {
            CPrintToChat(client, "%s{red}You already have a Whiskey Jug, you coward!", CHAT_PREFIX );
            return Plugin_Handled;
        }
        else {
            if ((GetUserFlagBits(client) & ADMFLAG_CUSTOM5) || (GetUserFlagBits(client) & ADMFLAG_ROOT))
            {
                SetEntPropFloat(client, Prop_Send, "m_flFoFCash", (GetEntPropFloat(client, Prop_Send, "m_flFoFCash") - (flWhiskeyJugPrice * 0.5)));
            }
            else {
                SetEntPropFloat(client, Prop_Send, "m_flFoFCash", (GetEntPropFloat(client, Prop_Send, "m_flFoFCash") - flWhiskeyJugPrice));
            }
            CPrintToChatAll("%s{green}Yee haw! {gold}%s{green} just purchased a Whiskey Jug. {gold}Pass the Whiskey!", CHAT_PREFIX, szClientName );
            EmitSoundToAll(SOUND_JUG);
            GivePlayerItem(client, "weapon_whiskey");
            g_Clients[client][(ClientData:hasJug)] = true;
            return Plugin_Handled;
        }
    }
    else if (!IsClientInGame(client))
    {
        CPrintToChat(client, "%s{red}Sorry, you gotta be playin' the game to drink whiskey!", CHAT_PREFIX );
        return Plugin_Handled;
    } 
    else if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s{red}You can't drink when you're a bucket of bones!", CHAT_PREFIX );
        return Plugin_Handled;
    } 
    else
    {
        CPrintToChat(client, "%s{red}Sorry, but we can't have any whiskey here!", CHAT_PREFIX );
        return Plugin_Handled;
    }
}