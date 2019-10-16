#pragma semicolon 1
#pragma newdecls required

#include <mapchooser_redux>
#include <smutils>

#undef REQUIRE_PLUGIN
#include <store>
#include <shop>
#define REQUIRE_PLUGIN


ArrayList g_aMapList;
ArrayList g_aOldList;
Menu g_hMapMenu;
int g_iMapFileSerial = -1;
bool g_pStore;
bool g_pShop;

#define MAPSTATUS_ENABLED (1<<0)
#define MAPSTATUS_DISABLED (1<<1)
#define MAPSTATUS_EXCLUDE_CURRENT (1<<2)
#define MAPSTATUS_EXCLUDE_PREVIOUS (1<<3)
#define MAPSTATUS_EXCLUDE_NOMINATED (1<<4)

StringMap g_smMaps;
StringMap g_smAuth;
StringMap g_smName;

public Plugin myinfo =
{
    name        = "Nominations Redux",
    author      = "Kyle",
    description = "Provides Map Nominations",
    version     = MCR_VERSION,
    url         = "https://kxnrl.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Store_GetClientCredits");
    MarkNativeAsOptional("Store_SetClientCredits");
    
    MarkNativeAsOptional("MG_Shop_ClientEarnMoney");
    MarkNativeAsOptional("MG_Shop_ClientCostMoney");

    return APLRes_Success;
}

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);
    SMUtils_SetTextDest(HUD_PRINTCENTER);
    
    LoadTranslations("com.kxnrl.mcr.translations");

    g_aMapList = new ArrayList(ByteCountToCells(256));
    g_aOldList = new ArrayList(ByteCountToCells(256));

    g_smMaps = new StringMap();
    g_smAuth = new StringMap();
    g_smName = new StringMap();
}

public void OnLibraryAdded(const char[] name)
{
    if(strcmp(name, "store") == 0)
        g_pStore = true;
    else if(strcmp(name, "shop-core") == 0)
        g_pShop = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if(strcmp(name, "store") == 0)
        g_pStore = false;
    else if(strcmp(name, "shop-core") == 0)
        g_pShop = false;
}

public void OnConfigsExecuted()
{
    g_pStore = LibraryExists("store");
    g_pShop = LibraryExists("shop-core");

    if(ReadMapList(g_aMapList, g_iMapFileSerial, "nominations", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
        if(g_iMapFileSerial == -1)
            SetFailState("Unable to create a valid map list.");

    CreateTimer(90.0, Timer_Broadcast, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    char map[128];
    GetCurrentMap(map, 128);
    g_smAuth.Remove(map);
    g_smName.Remove(map);

    if(g_hKvMapData != null)
        delete g_hKvMapData;
    g_hKvMapData = null;
}

public void OnNominationRemoved(const char[] map, int owner)
{
    int status;

    if(!g_smMaps.GetValue(map, status))
        return;    

    if((status & MAPSTATUS_EXCLUDE_NOMINATED) != MAPSTATUS_EXCLUDE_NOMINATED)
        return;

    g_smMaps.SetValue(map, MAPSTATUS_ENABLED);    
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if(!client)
        return;

    if(StrContains(sArgs, "nominat", false) == -1 && strcmp(sArgs, "nextmap", false) != 0)
        return;

    if(!IsNominateAllowed(client))
        return;
    
    if(sArgs[0] == '!' || sArgs[0] == '/' || sArgs[0] == '.')
    {
        char arg[2][128];
        ExplodeString(sArgs, " ", arg, 2, 128, true);
        if(strlen(arg[1]) >= 3)
        {
            FuzzyNominate(client, arg[1]);
            return;
        }
    }

    AttemptNominate(client);
}

void FuzzyNominate(int client, const char[] find)
{
    ArrayList result = new ArrayList(ByteCountToCells(128));
    
    char map[128];
    for(int x = 0; x < g_aMapList.Length; ++x)
    {
        g_aMapList.GetString(x, map, 128);
        if(StrContains(map, find, false) > -1)
            result.PushString(map);
    }
    
    if(result.Length == 0)
    {
        delete result;
        Chat(client, "%T", "NominateResult_NoMatch", client, find);
        AttemptNominate(client);
        return;
    }

    bool desctag = FindConVar("mcr_include_desctag").BoolValue;
    bool nametag = FindConVar("mcr_include_nametag").BoolValue;

    Menu menu = new Menu(Handler_MapSelectMenu);

    char desc[256];
    for(int x = 0; x < result.Length; ++x)
    {
        result.GetString(x, map, 128);
        menu.AddItem(map, desctag && GetMapDesc(map, desc, 256, true, nametag, (g_pStore || g_pShop)) ? desc : map);
    }

    menu.SetTitle("%d of %s", menu.ItemCount, find);
    menu.Display(client, MENU_TIME_FOREVER);

    delete result;
}

void AttemptNominate(int client)
{
    g_hMapMenu.SetTitle("%T\n ", "nominate menu title", client);
    g_hMapMenu.Display(client, MENU_TIME_FOREVER);
}

void BuildMapMenu()
{
    if(g_hMapMenu != null)
    {
        delete g_hMapMenu;
        g_hMapMenu = null;
    }

    g_smMaps.Clear();

    g_hMapMenu = new Menu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

    char map[128];

    g_aOldList.Clear();
    GetExcludeMapList(g_aOldList);

    char currentMap[32];
    GetCurrentMap(currentMap, 32);

    bool desctag = FindConVar("mcr_include_desctag").BoolValue;
    bool nametag = FindConVar("mcr_include_nametag").BoolValue;

    char desc[256];
    for(int i = 0; i < g_aMapList.Length; i++)
    {
        int status = MAPSTATUS_ENABLED;

        g_aMapList.GetString(i, map, 128);

        if(strcmp(map, currentMap) == 0)
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_CURRENT;

        if(status == MAPSTATUS_ENABLED)
            if(g_aOldList.FindString(map) != -1)
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS;
        g_hMapMenu.AddItem(map, desctag && GetMapDesc(map, desc, 256, true, nametag, (g_pStore || g_pShop)) ? desc : map);
        g_smMaps.SetValue(map, status);
    }

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

            NominateResult result = NominateMap(map, false, param1);

            if(result == NominateResult_NoCredits)
            {
                Chat(param1, "%T", "NominateResult_NoCredits", param1, map);
                return 0;
            }

            if(result == NominateResult_InvalidMap)
            {
                Chat(param1, "%T", "NominateResult_InvalidMap", param1, map);
                return 0;
            }

            if(result == NominateResult_AlreadyInVote)
            {
                Chat(param1, "%T", "NominateResult_AlreadyInVote", param1);
                return 0;
            }
            
            if(result == NominateResult_VoteFull)
            {
                Chat(param1, "%T", "NominateResult_VoteFull", param1);
                return 0;
            }
            
            if(result == NominateResult_OnlyAdmin)
            {
                Chat(param1, "%T", "NominateResult_OnlyAdmin", param1);
                return 0;
            }
            
            if(result == NominateResult_OnlyVIP)
            {
                Chat(param1, "%T", "NominateResult_OnlyVIP", param1);
                return 0;
            }

            if(result == NominateResult_MinPlayers)
            {
                Chat(param1, "%T", "NominateResult_MinPlayers", param1, GetMinPlayers(map));
                return 0;
            }
            
            if(result == NominateResult_MaxPlayers)
            {
                Chat(param1, "%T", "NominateResult_MaxPlayers", param1, GetMaxPlayers(map));
                return 0;
            }

            g_smMaps.SetValue(map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

            if(g_pStore)
            {
                int credits = GetMapPrice(map);
                Store_SetClientCredits(param1, Store_GetClientCredits(param1)-credits, "nomination-nominate");
                Chat(param1, "%T", "nominate nominate cost", param1, map, credits);
            }
            else if(g_pShop)
            {
                int credits = GetMapPrice(map);
                MG_Shop_ClientCostMoney(param1, credits, "nomination-nominate");
                Chat(param1, "%T", "nominate nominate cost", param1, map, credits);
            }

            char m_szAuth[32], m_szName[32];
            GetClientAuthId(param1, AuthId_Steam2, m_szAuth, 32, true);
            GetClientName(param1, m_szName, 32);
            g_smAuth.SetString(map, m_szAuth, true);
            g_smName.SetString(map, m_szName, true);

            LogMessage("[MCR]  \"%L\" nominated %s", param1, map);

            if(result == NominateResult_Replaced)
                tChatAll("%t", "nominate changed map", param1, map);
            else
                tChatAll("%t", "nominate nominate map", param1, map);

            if(FindConVar("mcr_include_desctag").BoolValue)
            {
                char desc[128];
                GetMapDesc(map, desc, 128, false, false);
                ChatAll("\x0A -> \x0E[\x05%s\x0E]", desc);
            }
        }

        case MenuAction_DrawItem:
        {
            char map[128];
            menu.GetItem(param2, map, 128);

            int status;

            if(!g_smMaps.GetValue(map, status))
            {
                LogError("case MenuAction_DrawItem: Menu selection of item not in trie. Major logic problem somewhere.");
                return ITEMDRAW_DISABLED; //ITEMDRAW_DEFAULT;
            }
            
            if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
                return ITEMDRAW_DISABLED;

            // players?
            int players = GetClientCount(false);
            int max = GetMaxPlayers(map);
            int min = GetMinPlayers(map);
            if ((max > 0 && players >= max) || (min > 0 && players < min))
                return ITEMDRAW_DISABLED;

            // admin or vip
            bool adm = IsOnlyAdmin(map);
            bool vip = IsOnlyVIP(map);
            if ((adm && !IsClientAdmin(param1)) || (vip && !IsClientVIP(param1)))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }
        
        case MenuAction_DisplayItem:
        {
            char map[128], display[150];
            menu.GetItem(param2, map, 128, _, display, 150);

            int status;
            
            if(!g_smMaps.GetValue(map, status))
            {
                LogError("case MenuAction_DisplayItem: Menu selection of item not in trie. Major logic problem somewhere.");
                return 0;
            }

            char trans[128];
            GetMapDesc(map, trans, 128, false, false, (g_pStore || g_pShop));

            if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
            {
                if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
                {
                    Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu current Map", param1);
                    return RedrawMenuItem(display);
                }

                if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
                {
                    int left = GetCooldown(map);
                    Format(display, sizeof(display), "%s\n%s (CD:%5d)", map, trans, left);
                    return RedrawMenuItem(display);
                }

                if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
                {
                    char name[32];
                    if(g_smName.GetString(map, name, 32))
                         Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu was nominated name", param1, name);
                    else Format(display, sizeof(display), "%s\n%s (%T)", map, trans, "nominate menu was nominated"     , param1);
                    return RedrawMenuItem(display);
                }
            }

            return 0;
        }
        
        case MenuAction_End:
        {
            if(menu != g_hMapMenu)
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
    }
    
    return true;
}

public void OnMapDataLoaded()
{
    if(g_hKvMapData != null)
        CloseHandle(g_hKvMapData);

    g_hKvMapData = new KeyValues("MapData", "", "");
    g_hKvMapData.ImportFromFile("addons/sourcemod/configs/mapdata.txt");
    g_hKvMapData.Rewind();

    BuildMapMenu();
}

int GetCooldown(const char[] map)
{
    int listlimit = FindConVar("mcr_maps_history_count").IntValue;
    int currindex = g_aOldList.FindString(map) + 1;
    if (g_aOldList.Length == listlimit)
    {
        return currindex;
    }
    return (listlimit - g_aOldList.Length) + currindex;
}

public Action Timer_Broadcast(Handle timer)
{
    char map[128];
    GetCurrentMap(map, 128);
    
    char m_szAuth[32];
    if(!g_smAuth.GetString(map, m_szAuth, 32))
        return Plugin_Stop;
    
    char m_szName[32];
    if(!g_smName.GetString(map, m_szName, 32))
        return Plugin_Stop;
    
    int client = FindClientByAuth(m_szAuth);

    if(!client)
        tChatAll("%t", "nominated by name", m_szName, m_szAuth[8]);
    else
        tChatAll("%t", "nominated by client", client, m_szAuth[8]);

    return Plugin_Continue;
}

int FindClientByAuth(const char[] steamid)
{
    char m_szAuth[32];
    for(int client = 1; client <= MaxClients; ++client)
        if(IsClientAuthorized(client))
            if(GetClientAuthId(client, AuthId_Steam2, m_szAuth, 32, true))
                if(StrEqual(m_szAuth, steamid))
                    return client;

    return 0;
}