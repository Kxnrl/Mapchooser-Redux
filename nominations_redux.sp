#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mapchooser_redux>
#include <smutils>

#undef REQUIRE_PLUGIN
#include <fys.pupd>

ArrayList g_aMapList;
ArrayList g_aOldList;
Menu g_hMapMenu;
int g_iMapFileSerial = -1;
bool g_pStore;
bool g_pShop;

bool g_bPartyblock[MAXPLAYERS+1];

#define MAPSTATUS_ENABLED (1<<0)
#define MAPSTATUS_DISABLED (1<<1)
#define MAPSTATUS_EXCLUDE_CURRENT (1<<2)
#define MAPSTATUS_EXCLUDE_PREVIOUS (1<<3)
#define MAPSTATUS_EXCLUDE_NOMINATED (1<<4)

enum struct owner_t
{
    char m_Auth[32];
    char m_Name[32];
}

StringMap g_smOwner;
StringMap g_smState;

ConVar mcr_broadcast_nomination_owner;

public Plugin myinfo =
{
    name        = "Nominations Redux",
    author      = "Kyle",
    description = "Provides Map Nominations",
    version     = MCR_VERSION,
    url         = "https://www.kxnrl.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Pupd_CheckPlugin");
    return APLRes_Success;
}

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);
    SMUtils_SetTextDest(HUD_PRINTCENTER);
    
    LoadTranslations("com.kxnrl.mcr.translations");

    g_aMapList = new ArrayList(ByteCountToCells(128));
    g_aOldList = new ArrayList(ByteCountToCells(128));

    g_smState = new StringMap();
    g_smOwner = new StringMap();

    RegConsoleCmd("nominate",   Command_Nominate);
    RegConsoleCmd("nomination", Command_Nominate);
    RegConsoleCmd("sm_yd",      Command_Nominate);
    RegConsoleCmd("sm_nlist",   Command_NList);
    RegConsoleCmd("sm_ydlb",    Command_NList);

    RegConsoleCmd("sm_bc",      Command_Partyblock);
    RegConsoleCmd("partyblock", Command_Partyblock);

    mcr_broadcast_nomination_owner = CreateConVar("mcr_broadcast_nomination_owner", "1", "Boradcast nomination owner message of current map every 90 seconds.", _, true, 0.0, true, 1.0);

    if (!DirExists("cfg/sourcemod/mapchooser"))
        if (!CreateDirectory("cfg/sourcemod/mapchooser", 511))
            SetFailState("Failed to create folder \"cfg/sourcemod/mapchooser\"");

    AutoExecConfig(true, "nominations_redux", "sourcemod/mapchooser");
}

public void OnAllPluginsLoaded()
{
    g_pStore = LibraryExists("store");
    g_pShop = LibraryExists("shop-core");
}

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MCR/");
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "store") == 0)
        g_pStore = true;
    else if (strcmp(name, "shop-core") == 0)
        g_pShop = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "store") == 0)
        g_pStore = false;
    else if (strcmp(name, "shop-core") == 0)
        g_pShop = false;
}

public void OnConfigsExecuted()
{
    if (ReadMapList(g_aMapList, g_iMapFileSerial, "nominations", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
        if (g_iMapFileSerial == -1)
            SetFailState("Unable to create a valid map list.");

    CreateTimer(90.0, Timer_Broadcast, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    char map[128];
    GetCurrentMap(map, 128);
    g_smOwner.Remove(map);
}

public void OnNominationRemoved(const char[] map, int client, bool partyblock)
{
    int status;

    if (!g_smState.GetValue(map, status))
        return;

    if ((status & MAPSTATUS_EXCLUDE_NOMINATED) != MAPSTATUS_EXCLUDE_NOMINATED)
        return;

    g_smState.SetValue(map, MAPSTATUS_ENABLED);    
}

public Action Command_Nominate(int client, int args)
{
    if (!client)
        return Plugin_Handled;

    if (!IsNominateAllowed(client))
        return Plugin_Handled;

    g_bPartyblock[client] = false;

    if (args < 1)
    {
        AttemptNominate(client);
        return Plugin_Handled;
    }

    char map[32];
    GetCmdArg(1, map, 32);
    if (strlen(map) >= 3)
    {
        FuzzyNominate(client, map);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action Command_Partyblock(int client, int args)
{
    if (!client)
        return Plugin_Handled;

    if (!IsNominateAllowed(client))
        return Plugin_Handled;

    g_bPartyblock[client] = true;

    if (args < 1)
    {
        AttemptNominate(client);
        return Plugin_Handled;
    }

    char map[32];
    GetCmdArg(1, map, 32);
    if (strlen(map) >= 3)
    {
        FuzzyNominate(client, map);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action Command_NList(int client, int args)
{
    if (!client)
        return Plugin_Handled;

    if (HasEndOfMapVoteFinished())
    {
        FakeClientCommandEx(client, "nextmap");
        return Plugin_Handled;
    }

    DisplayNominationList(client);

    return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if (!client || sArgs[0] == '!' || sArgs[0] == '/' || sArgs[0] == '.')
        return;

    if (StrContains(sArgs, "nominat", false) == -1)
        return;

    if (!IsNominateAllowed(client))
        return;

    g_bPartyblock[client] = false;
    AttemptNominate(client);
}

void FuzzyNominate(int client, const char[] find)
{
    ArrayList result = new ArrayList(ByteCountToCells(128));
    
    char map[128];
    for(int x = 0; x < g_aMapList.Length; ++x)
    {
        g_aMapList.GetString(x, map, 128);
        if (StrContains(map, find, false) > -1)
            result.PushString(map);
    }
    
    if (result.Length == 0)
    {
        delete result;
        Chat(client, "%T", "NominateResult_NoMatch", client, find);
        AttemptNominate(client);
        return;
    }

    bool desctag = FindConVar("mcr_include_desctag").BoolValue;
    bool nametag = FindConVar("mcr_include_nametag").BoolValue;
    bool tiertag = FindConVar("mcr_include_tiertag").BoolValue;

    Menu menu = new Menu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

    char desc[128];
    for(int x = 0; x < result.Length; ++x)
    {
        result.GetString(x, map, 128);
        menu.AddItem(map, desctag && GetMapDescEx(map, desc, 128, true, nametag, (g_pStore || g_pShop), tiertag) ? desc : map);
    }

    menu.SetTitle("%T", "fuzzy title", client, menu.ItemCount, find, g_bPartyblock[client] ? "partyblock nominate menu item" : "nominate nominate menu item", client);
    
    
    menu.Pagination = 5;
    menu.Display(client, MENU_TIME_FOREVER);

    delete result;
}

void AttemptNominate(int client)
{
    if (g_hMapMenu.ItemCount == 0)
    {
        Chat(client, "%T", "nominate not allowed", client);
        return;
    }

    g_hMapMenu.SetTitle("%T\n ", g_bPartyblock[client] ? "partyblock menu title" : "nominate menu title", client);
    g_hMapMenu.Display(client, MENU_TIME_FOREVER);
}

void BuildMapMenu()
{
    if (g_hMapMenu != null)
    {
        delete g_hMapMenu;
        g_hMapMenu = null;
    }

    g_smState.Clear();

    g_hMapMenu = new Menu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

    g_aOldList.Clear();
    GetExcludeMapList(g_aOldList);

    char currentMap[64];
    GetCurrentMap(currentMap, 64);

    bool desctag = FindConVar("mcr_include_desctag").BoolValue;
    bool nametag = FindConVar("mcr_include_nametag").BoolValue;
    bool tiertag = FindConVar("mcr_include_tiertag").BoolValue;

    char desc[128], map[128]; Nominations n;
    for(int i = 0; i < g_aMapList.Length; i++)
    {
        int status = MAPSTATUS_ENABLED;

        g_aMapList.GetString(i, map, 128);

        if (strcmp(map, currentMap) == 0)
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_CURRENT;
        else if (GetNominated(map, n))
        {
            owner_t owner;
            GetClientAuthId(n.m_Owner, AuthId_SteamID64, owner.m_Auth, 32, false);
            GetClientName(n.m_Owner, owner.m_Name, 25);
            g_smOwner.SetArray(map, owner, sizeof(owner_t), true);
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED;
        }
        else
        {
            if (g_aOldList.FindString(map) != -1)
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS;
        }

        g_hMapMenu.AddItem(map, desctag && GetMapDescEx(map, desc, 128, true, nametag, (g_pStore || g_pShop), tiertag) ? desc : map);
        g_smState.SetValue(map, status);
    }

    g_hMapMenu.Pagination = 5;
    g_hMapMenu.ExitButton = true;
}

public int Handler_MapSelectMenu(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char map[128];
            menu.GetItem(param2, map, 128);        

            NominateResult result = NominateMap(map, false, param1, g_bPartyblock[param1]);

            if (result == NominateResult_Reject)
            {
                // reject by api
                return 0;
            }

            if (result == NominateResult_NoCredits)
            {
                Chat(param1, "%T", "NominateResult_NoCredits", param1, map);
                return 0;
            }

            if (result == NominateResult_InvalidMap)
            {
                Chat(param1, "%T", "NominateResult_InvalidMap", param1, map);
                return 0;
            }

            if (result == NominateResult_AlreadyInVote)
            {
                Chat(param1, "%T", "NominateResult_AlreadyInVote", param1);
                return 0;
            }
            
            if (result == NominateResult_VoteFull)
            {
                Chat(param1, "%T", "NominateResult_VoteFull", param1);
                return 0;
            }

            int min, max; bool vip, adm;
            GetMapPermission(map, vip, adm, min, max);

            if (result == NominateResult_AdminOnly)
            {
                Chat(param1, "%T", "NominateResult_AdminOnly", param1);
                return 0;
            }
            
            if (result == NominateResult_VIPOnly)
            {
                Chat(param1, "%T", "NominateResult_VIPOnly", param1);
                return 0;
            }

            if (result == NominateResult_CertainTimes)
            {
                Chat(param1, "%T", "NominateResult_CertainTimes", param1);
                return 0;
            }

            if (result == NominateResult_MinPlayers)
            {
                Chat(param1, "%T", "NominateResult_MinPlayers", param1, min);
                return 0;
            }
            
            if (result == NominateResult_MaxPlayers)
            {
                Chat(param1, "%T", "NominateResult_MaxPlayers", param1, max);
                return 0;
            }

            if (result == NominateResult_RecentlyPlayed)
            {
                Chat(param1, "%T", "NominateResult_RecentlyPlayed", param1);
                return 0;
            }

            if (result == NominateResult_PartyBlock)
            {
                Chat(param1, "%T", "NominateResult_PartyBlock", param1);
                return 0;
            }

            if (result == NominateResult_PartyBlockDisabled)
            {
                Chat(param1, "%T", "NominateResult_PartyBlockDisabled", param1);
                return 0;
            }

            g_smState.SetValue(map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED, true);

            if (result == NominateResult_PartyBlockAdded)
            {
                tChatAll("%t", "nominate partyblock map", param1, map);
                LogMessage("[MCR]  \"%L\" partyblock %s", param1, map);
            }
            else
            {
                if (result == NominateResult_Replaced)
                    tChatAll("%t", "nominate changed map", param1, map);
                else
                    tChatAll("%t", "nominate nominate map", param1, map);

                LogMessage("[MCR]  \"%L\" nominated %s", param1, map);
            }

            char desc[128];
            if (GetMapDescEx(map, desc, 128, false, false, false, FindConVar("mcr_include_tiertag").BoolValue))
            {
                SMUtils_SkipNextPrefix();
                ChatAll("\x0E ➤ \x0E ➢ \x0E ➣ \x01  \x0A[\x05%s\x0A]", desc);
            }
        }

        case MenuAction_DrawItem:
        {
            char map[128];
            menu.GetItem(param2, map, 128);

            int status;

            if (!g_smState.GetValue(map, status))
            {
                LogError("case MenuAction_DrawItem: Menu selection of item not in trie. Major logic problem somewhere.");
                return ITEMDRAW_DISABLED;
            }
            
            if ((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
                return ITEMDRAW_DISABLED;

            int min, max; // players = GetClientCount(false);
            bool adm, vip;
            if (!GetMapPermission(map, vip, adm, min, max))
                return ITEMDRAW_DISABLED;

            // players?
            //if ((max > 0 && players >= max) || (min > 0 && players < min))
            //    return ITEMDRAW_DISABLED;

            // admin or vip
            if ((adm && !IsClientAdmin(param1)) || (vip && !IsClientVIP(param1)))
                return ITEMDRAW_DISABLED;

            if (IsNominated(map))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }

        case MenuAction_DisplayItem:
        {
            char map[128], display[150];
            menu.GetItem(param2, map, 128, _, display, 150);

            int status;
            
            if (!g_smState.GetValue(map, status))
            {
                LogError("case MenuAction_DisplayItem: Menu selection of item not in trie. Major logic problem somewhere.");
                return 0;
            }

            char trans[128];
            GetMapDescEx(map, trans, 128, false, true, false, FindConVar("mcr_include_tiertag").BoolValue);
            if (g_pStore || g_pShop)
            {
                Format(trans, 128, "%s [%T: %d]", trans, g_bPartyblock[param1] ? "partyblock nominate menu item" : "nominate nominate menu item", param1, GetMapPrice(map, true, g_bPartyblock[param1]));
            }

            if ((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
            {
                if ((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
                {
                    Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu current Map", param1);
                    return RedrawMenuItem(display);
                }

                if ((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
                {
                    Format(display, sizeof(display), "%s\n%s (CD: %5d)", map, trans, GetMapCooldown(map));
                    return RedrawMenuItem(display);
                }

                if ((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
                {
                    owner_t owner;
                    if (g_smOwner.GetArray(map, owner, sizeof(owner_t)))
                         Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu was nominated name", param1, owner.m_Name);
                    else Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu was nominated"     , param1);
                    return RedrawMenuItem(display);
                }
            }

            Nominations n;
            if (GetNominated(map, n))
            {
                char name[25];
                GetClientName(n.m_Owner, name, 25);
                Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu was nominated name", param1, name);
                return RedrawMenuItem(display);
            }

            Format(display, sizeof(display), "%s\n%s", map, trans);
            return RedrawMenuItem(display);
        }

        case MenuAction_End:
        {
            if (menu != g_hMapMenu)
                delete menu;
        }
    }

    return 0;
}

stock bool IsNominateAllowed(int client)
{
    CanNominateResult result = CanNominate();
    
    switch(result)
    {
        case CanNominate_No_VoteInProgress:
        {
            Chat(client, "%T", "nominate vote in progress", client);
            return false;
        }

        case CanNominate_No_VoteComplete:
        {
            char map[128];
            GetNextMap(map, 128);
            Chat(client, "%T", "nominate vote complete", client, map);
            return false;
        }
        
        case CanNominate_No_VoteFull:
        {
            Chat(client, "%T", "nominate full vote", client);
            return false;
        }

        case CanNominate_No_PartyBlock:
        {
            Chat(client, "%T", "nominate partyblock", client, GetPartyBlockOnwer());
            return false;
        }
    }
    
    return true;
}

public void OnMapVotePoolChanged()
{
    BuildMapMenu();
}

public Action Timer_Broadcast(Handle timer)
{
    if (!mcr_broadcast_nomination_owner.BoolValue)
        return Plugin_Continue;

    char map[128];
    GetCurrentMap(map, 128);
    
    owner_t owner;
    if (!g_smOwner.GetArray(map, owner, sizeof(owner_t)))
        return Plugin_Stop;

    int client = FindClientByAuth(owner.m_Auth);

    if (!client)
        tChatAll("%t", "nominated by name", owner.m_Name, owner.m_Auth[8]);
    else
        tChatAll("%t", "nominated by client", client, owner.m_Auth[8]);

    return Plugin_Continue;
}

int FindClientByAuth(const char[] steamid)
{
    char m_szAuth[32];
    for(int client = 1; client <= MaxClients; ++client)
        if (IsClientAuthorized(client))
            if (GetClientAuthId(client, AuthId_SteamID64, m_szAuth, 32, true))
                if (StrEqual(m_szAuth, steamid))
                    return client;

    return 0;
}

public void OnNominationVoted(const char[] map, const char[] name, const char[] auth)
{
    owner_t owner;
    strcopy(owner.m_Auth, 32, auth);
    strcopy(owner.m_Name, 32, name);
    g_smOwner.SetArray(map, owner, sizeof(owner_t), true);
}

void DisplayNominationList(int client)
{
    ArrayList list = new ArrayList(sizeof(Nominations));
    GetNominatedMapList(list);
    if (list.Length == 0)
    {
        delete list;
        Chat(client, "%T", "no nlist", client);
        return;
    }

    Menu menu = new Menu(MenuHandler_NList);

    menu.SetTitle("%t\n ", "nlist title", list.Length);

    for (int i = 0; i < list.Length; i++)
    {
        Nominations n;
        char buffer[128];
        list.GetArray(i, n, sizeof(Nominations));
        if (GetMapDescEx(n.m_Map, buffer, 128, false, false, false, FindConVar("mcr_include_tiertag").BoolValue))
        {
            Format(buffer, 128, "%s\n%s [by: %s]", n.m_Map, buffer, n.m_OwnerName);
        }
        else
        {
            Format(buffer, 128, "%s\n [by: %s]", n.m_Map, n.m_OwnerName);
        }
        
        menu.AddItem("Lilia", buffer, ITEMDRAW_DISABLED);
    }

    menu.Display(client, 10);

    delete list;
}

static int MenuHandler_NList(Menu menu, MenuAction action, int client, int slot)
{
    if (action == MenuAction_End)
        delete menu;

    return 0;
}