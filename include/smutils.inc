/******************************************************************/
/*                                                                */
/*                         Sourcemod UTILs                        */
/*                                                                */
/*                                                                */
/*  File:          smutils.inc                                    */
/*  Description:   Some helpful functions.                        */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle   https://kxnrl.com                  */
/*  2018/04/04 10:17:14                                           */
/*                                                                */
/*  This code is licensed under the GPLv3 License.                */
/*                                                                */
/******************************************************************/


#if defined __SourceMod_UTILs__
    #endinput
#endif

#define __SourceMod_UTILs__

#define SMUtils_Version "1.2.0"
#define SMUtils_Author  "Kyle"
#define SMUtils_URL     "https://github.com/Kxnrl/sourcemod-utils"

#define CONSOLE    0
#define MinClients 1

#undef REQUIRE_EXTENSIONS
#include <sdktools>
#define REQUIRE_EXTENSIONS

#if !defined DMG_HEADSHOT
    #define DMG_HEADSHOT (1 << 31)
#endif


/**************************
            Global
**************************/
stock bool ClientIsKyle(int client)
{
    int account = GetSteamAccountID(client);
    return (account == 88166525 || account == 6678492);
}

stock int GetKyleIndex()
{
    return FindClientByAccount(88166525);
}


/**************************
            Client
**************************/
stock bool ClientIsValid(int client, bool allowBot = false)
{
    if(client > MaxClients || client < MinClients)
        return false;
    
    if(!IsClientConnected(client))
        return false;

    if(!IsClientInGame(client))
        return false;

    if(IsClientSourceTV(client) || IsClientReplay(client))
        return false;

    return (!IsFakeClient(client)) || allowBot;
}

stock bool ClientIsAlive(int client, bool allowBot = false)
{
    if(client > MaxClients || client < MinClients)
        return false;

    if(!IsClientInGame(client))
        return false;

    if(IsClientSourceTV(client) || IsClientReplay(client))
        return false;
    
    if(!allowBot && IsFakeClient(client))
        return false;

    return IsPlayerAlive(client);
}

stock int FindClientByAccount(int account, bool validate = false)
{
    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
            if(GetSteamAccountID(client) == account)
                return client;

    return -1;
}

stock int FindClientBySteamId(AuthIdType authType, const char[] authId, bool validate = false)
{
    char steamId[32];
    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
            if(GetClientAuthId(client, authType, steamId, 32, validate))
                if(strcmp(steamId, authId) == 0)
                    return client;

    return -1;
}

stock int GetRandomClient(bool alive = false, int ignoreFlags = 0)
{
    int[] clients = new int [MaxClients+1];
    int total;

    clients[total++] = -1;

    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
            if(!alive || ClientIsAlive(client))
                if((ignoreFlags != 0 && HasClientUserFlags(client, ignoreFlags)) || ignoreFlags == 0) 
                    clients[total++] = client;
    
    return clients[RandomInt(0, total)];
}

stock bool HasClientUserFlags(int client, int flags)
{
    int clientFlags = GetUserFlagBits(client);
    return (clientFlags & ADMFLAG_ROOT || clientFlags & flags);
}

stock bool HasClientAdminFlags(int client, AdminFlag flag)
{
    char steamid[32];
    
    //try all steamId type
    for(int i = 0; i < view_as<int>(AuthIdType); ++i)
    {
        GetClientAuthId(client, view_as<AuthIdType>(i), steamid, 32);
        AdminId admin = FindAdminByIdentity(steamid, AUTHMETHOD_STEAM);
        if(admin != INVALID_ADMIN_ID)
            return (admin.HasFlag(flag, Access_Real) || admin.HasFlag(flag, Access_Effective));
    }
    
    return false;
}

stock void SetClientFrags(int client, int val)
{
    SetEntProp(client, Prop_Data, "m_iFrags", val);
}

stock void SetClientDeaths(int client, int val)
{
    SetEntProp(client, Prop_Data, "m_iDeaths", val);
}

stock void SetClientMoney(int client, int val)
{
    SetEntProp(client, Prop_Send, "m_iAccount", val);
}

stock void SetClientKevlar(int client, int val)
{
    SetEntProp(client, Prop_Send, "m_ArmorValue", val);
}

stock void SetClientHelmet(int client, bool has)
{
    SetEntProp(client, Prop_Send, "m_bHasHelmet", has);
}

stock void SetClientHud(int client, int val)
{
    SetEntProp(client, Prop_Send, "m_iHideHUD", val);
}

stock void SetClientWallHack(int client, float time) // time = GetGameTime() + val
{
    SetEntPropFloat(client, Prop_Send, "m_flDetectedByEnemySensorTime", 0.0);
}

stock int GetClientAimTargetPos(int client, float pos[3])
{
    float fAgl[3];
    float fOrg[3];

    GetClientEyePosition(client,fOrg);
    GetClientEyeAngles(client, fAgl);

    Handle trace = TR_TraceRayFilterEx(fOrg, fAgl, MASK_SHOT, RayType_Infinite, TraceFilterAllEntities_smuils_TFAE, client);

    TR_GetEndPosition(pos, trace);

    int entity = TR_GetEntityIndex(trace);

    delete trace;

    return entity;
}

public bool TraceFilterAllEntities_smuils_TFAE(int entity, int contentsMask, int client)
{
    return (entity == client || entity > MaxClients || entity < MinClients) ? false : true;
}

stock int GetTeamPlayers(int team, bool alive = false)
{
    int total = 0;
    for(int client = 1; client <= MaxClients; ++client)
        if(ClientIsValid(client) && GetClientTeam(team) == team)
        {
            if(alive && !IsPlayerAlive(client))
                continue;
            
            total++;
        }
    return total;
}

stock int GetPlayers(bool ingame = true, bool alive = false)
{
    int total = 0;
    for(int client = 1; client <= MaxClients; ++client)
        if(IsClientConnected(client))
        {
            if(ingame && !IsClientInGame(client))
                continue;
            
            if(alive && IsClientInGame(client) && !IsPlayerAlive(client))
                continue;

            total++;
        }
    return total;
}

stock int GetPlayersEx(bool alive = false, int &tes, int &cts)
{
    tes = 0;
    cts = 0;
    int total = 0;
    int iTeam = 1;
    for(int client = 1; client <= MaxClients; ++client)
        if(IsClientInGame(client))
        {
            if(alive && !IsPlayerAlive(client))
                continue;

            iTeam = GetClientTeam(client);
            
            if(iTeam == 2)
                tes++;
            else if(iTeam == 3)
                cts++;

            total++;
        }
    return total;
}

/**************************
            SteamId
**************************/
stock int ConvertSteam64ToSteam32(const char[] steamId64, char[] steamId32, int maxLen)
{
    if(strlen(steamId64) != 17 || StrContains(steamId64, "765611", false) != 0)
    {
        ThrowNativeError(SP_ERROR_PARAM, "ConvertSteam64ToSteam32 -> Invalid steamId64 given. -> %s", steamId64);
        return -1;
    }

    char[] m_szBase = "76561197960265728";
    char m_szAuth[18], m_szAccount[18];
    int m_iBorrow, m_iTemp, m_iSteamId[2];

    strcopy(m_szAuth, 18, steamId64);

    if(CharToNumber(m_szAuth[16]) % 2 == 1)
    {
        m_iSteamId[0] = 1;
        m_szAuth[16] = NumberToChar(CharToNumber(m_szAuth[16]) - 1);
    }
    
    for(int k = 16; k >= 0; k--)
    {
        if(m_iBorrow > 0)
        {
            m_iTemp = CharToNumber(m_szAuth[k]) - 1;

            if(m_iTemp >= CharToNumber(m_szBase[k]))
            {
                m_iBorrow = 0;
                m_szAccount[k] = NumberToChar(m_iTemp - CharToNumber(m_szBase[k]));
            }
            else
            {
                m_iBorrow = 1;
                m_szAccount[k] = NumberToChar((m_iTemp + 10) - CharToNumber(m_szBase[k]));
            }
        }
        else
        {
            if(CharToNumber(m_szAuth[k]) >= CharToNumber(m_szBase[k]))
            {
                m_iBorrow = 0;
                m_szAccount[k] = NumberToChar(CharToNumber(m_szAuth[k]) - CharToNumber(m_szBase[k]));
            }
            else
            {
                m_iBorrow = 1;
                m_szAccount[k] = NumberToChar((CharToNumber(m_szAuth[k]) + 10) - CharToNumber(m_szBase[k]));
            }
        }
    }

    m_iSteamId[1] = StringToInt(m_szAccount);
    m_iSteamId[1] /= 2;

    return FormatEx(steamId32, maxLen, "STEAM_1:%d:%d", m_iSteamId[0], m_iSteamId[1]);
}

stock int NumberToChar(const int iNum)
{
    return '0' + ((iNum >= 0 && iNum <= 9) ? iNum : 0);
}

stock int CharToNumber(const int cNum)
{
    return (cNum >= '0' && cNum <= '9') ? (cNum - '0') : 0;
}


/**************************
            Date
**************************/
stock int GetToday(int unix_timestamp = 0)
{
    char m_szDate[32];
    FormatTime(m_szDate, 32, "%Y%m%d", unix_timestamp == 0 ? GetTime() : unix_timestamp);
    return StringToInt(m_szDate);
}

stock int GetTodayHours(int unix_timestamp = 0)
{
    char m_szDate[32];
    FormatTime(m_szDate, 32, "%H", unix_timestamp == 0 ? GetTime() : unix_timestamp);
    return StringToInt(m_szDate);
}

stock void GetDate(int unix_timestamp = 0, const char[] format = "%Y/%m/%d %H:%M:%S", char[] buffer, int maxLen)
{
    FormatTime(buffer, maxLen, format, unix_timestamp == 0 ? GetTime() : unix_timestamp);
}

/**************************
            Chat
**************************/
static char ChatPrefix[64] = "[\x04SM\x01]";
static char ChatSpaces[32] = "   ";
static bool ChatConSnd     = true;
static bool SkipNextChatCS = false;
static bool SkipNextPrefix = false;
static bool ReplaceColorEx = false;
static UserMessageType UMType = UM_Protobuf;
static EngineVersion GameEngine = Engine_CSGO;

stock void SMUtils_InitUserMessage()
{
    UMType = GetUserMessageType();
    GameEngine = GetEngineVersion();

    if(GameEngine == Engine_Insurgency || GameEngine == Engine_Left4Dead2)
    {
        ReplaceColorEx = true;
    }
    else if(GameEngine == Engine_CSGO)
    {
        ReplaceColorEx = false;
    }
    else
    {
        SetFailState("Current Engine not suppoirted");
    }
}

stock int SMUtils_SetChatPrefix(const char[] prefix)
{
    return strcopy(ChatPrefix, 64, prefix);
}

stock int SMUtils_SetChatSpaces(const char[] spaces)
{
    return strcopy(ChatSpaces, 32, spaces);
}

// Set Chat string log in console and chat sound?
stock void SMUtils_SetChatConSnd(bool consnd)
{
    ChatConSnd = consnd;
}

// set next chat stop sound and log
stock void SMUtils_SkipNextChatCS()
{
    SkipNextChatCS = true;
}

// set next chat ignore prefix
stock void SMUtils_SkipNextPrefix()
{
    SkipNextPrefix = true;
}

stock void Chat(int client, const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 3);
    Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
    ProcessColorString(msg, 256);
    SMUtils_SayText2(client, msg);
    SkipNextChatCS = false;
    SkipNextPrefix = false;
}

stock void ChatEx(int[] clients, int numClients, const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 4);
    Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
    ProcessColorString(msg, 256);
    
    if(UMType == UM_Protobuf)
    {
        Protobuf SayText2 = view_as<Protobuf>(StartMessage("SayText2", clients, numClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        SayText2.SetInt("ent_idx", 0);
        SayText2.SetBool("chat", SkipNextChatCS ? false : ChatConSnd);
        SayText2.SetString("msg_name", msg);
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        EndMessage();
    }
    else
    {
        BfWrite SayText = view_as<BfWrite>(StartMessage("SayText", clients, numClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        SayText.WriteByte(0);
        SayText.WriteByte(true);
        SayText.WriteString(msg);
        EndMessage();
    }

    SkipNextChatCS = false;
    SkipNextPrefix = false;
}

stock void ChatTeam(int team, bool spec = true, const char[] buffer, any ...)
{
    int[] clients = new int [MAXPLAYERS+1];
    int total = 0;
    int iTeam = 0;
    
    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
        {
            iTeam = GetClientTeam(client);
            if(iTeam == team || (spec && iTeam == 1))
                clients[total++] = client;
        }

    char message[256];
    VFormat(message, 256, buffer, 4);
    ChatEx(clients, total, message);
}

stock void ChatAlive(bool alive, bool spec = true, const char[] buffer, any ...)
{
    int[] clients = new int [MAXPLAYERS+1];
    int total = 0;

    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
        {
            if((alive == IsPlayerAlive(client)) || (spec && GetClientTeam(client) == 1))
                clients[total++] = client;
        }
        
    char message[256];
    VFormat(message, 256, buffer, 4);
    ChatEx(clients, total, message);
}

stock void ChatAll(const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 2);
    Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
    ProcessColorString(msg, 256);

    if(UMType == UM_Protobuf)
    {
        Protobuf SayText2 = view_as<Protobuf>(StartMessageAll("SayText2", USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        SayText2.SetInt("ent_idx", 0);
        SayText2.SetBool("chat", SkipNextChatCS ? false : ChatConSnd);
        SayText2.SetString("msg_name", msg);
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        EndMessage();
    }
    else
    {
        BfWrite SayText = view_as<BfWrite>(StartMessageAll("SayText", USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        SayText.WriteByte(0);
        SayText.WriteByte(true);
        SayText.WriteString(msg);
        EndMessage();
    }

    SkipNextChatCS = false;
    SkipNextPrefix = false;
}

stock void tChat(int client, const char[] buffer, any ...)
{
    char msg[256];
    SetGlobalTransTarget(client);
    VFormat(msg, 256, buffer, 3);
    Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
    ProcessColorString(msg, 256);
    SMUtils_SayText2(client, msg);
    SkipNextChatCS = false;
    SkipNextPrefix = false;
    SetGlobalTransTarget(LANG_SERVER);
}

stock void tChatAlive(bool alive, bool spec = true, const char[] buffer, any ...)
{
    char msg[256];
    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
        {
            if((alive == IsPlayerAlive(client)) || (spec && GetClientTeam(client) == 1))
            {
                SetGlobalTransTarget(client);
                VFormat(msg, 256, buffer, 4);
                Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
                ProcessColorString(msg, 256);
                SMUtils_SayText2(client, msg);
            }
        }
    
    SkipNextChatCS = false;
    SkipNextPrefix = false;
    SetGlobalTransTarget(LANG_SERVER);
}

stock void tChatTeam(int team, bool spec = true, const char[] buffer, any ...)
{
    int iTeam = 0;
    char msg[256];

    for(int client = 1; client <= MaxClients; client++)
        if(ClientIsValid(client))
        {
            iTeam = GetClientTeam(client);
            if(iTeam == team || (spec && iTeam == 1))
            {
                SetGlobalTransTarget(client);
                VFormat(msg, 256, buffer, 4);
                Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
                ProcessColorString(msg, 256);
                SMUtils_SayText2(client, msg);
            }
        }

    SkipNextChatCS = false;
    SkipNextPrefix = false;
    SetGlobalTransTarget(LANG_SERVER);
}

stock void tChatAll(const char[] buffer, any ...)
{
    char msg[256];
    for(int client = 1; client <= MaxClients; ++client)
        if(ClientIsValid(client))
        {
            SetGlobalTransTarget(client);
            VFormat(msg, 256, buffer, 2);
            Format(msg, 256, "%s%s%s", !SkipNextPrefix ? ChatPrefix : "", ChatSpaces, msg);
            ProcessColorString(msg, 256);
            SMUtils_SayText2(client, msg);
        }

    SkipNextChatCS = false;
    SkipNextPrefix = false;
    SetGlobalTransTarget(LANG_SERVER);
}

stock void ProcessColorString(char[] message, int maxLen)
{
    if(ReplaceColorEx)
    {
        ReplaceString(message, maxLen, "{normal}",      "\x07FFFFFF", false);
        ReplaceString(message, maxLen, "{default}",     "\x07FFFFFF", false);
        ReplaceString(message, maxLen, "{white}",       "\x07FFFFFF", false);
        ReplaceString(message, maxLen, "{darkred}",     "\x07FF0000", false);
        ReplaceString(message, maxLen, "{pink}",        "\x07D32CE6", false);
        ReplaceString(message, maxLen, "{green}",       "\x077FFF00", false);
        ReplaceString(message, maxLen, "{lime}",        "\x07BFFF00", false);
        ReplaceString(message, maxLen, "{yellow}",      "\x07FFD700", false);
        ReplaceString(message, maxLen, "{lightgreen}",  "\x0798FB98", false);
        ReplaceString(message, maxLen, "{lightred}",    "\x07EB4B4B", false);
        ReplaceString(message, maxLen, "{red}",         "\x07DC143C", false);
        ReplaceString(message, maxLen, "{gray}",        "\x07DCDCDC", false);
        ReplaceString(message, maxLen, "{grey}",        "\x07DCDCDC", false);
        ReplaceString(message, maxLen, "{olive}",       "\x07808000", false);
        ReplaceString(message, maxLen, "{orange}",      "\x07E4AE39", false);
        ReplaceString(message, maxLen, "{silver}",      "\x07B0C3D9", false);
        ReplaceString(message, maxLen, "{lightblue}",   "\x075E98D9", false);
        ReplaceString(message, maxLen, "{blue}",        "\x074B69FF", false);
        ReplaceString(message, maxLen, "{purple}",      "\x078847FF", false);
        ReplaceString(message, maxLen, "{darkorange}",  "\x07CF6A32", false);
    }
    else
    {
        ReplaceString(message, maxLen, "{normal}",      "\x01", false);
        ReplaceString(message, maxLen, "{default}",     "\x01", false);
        ReplaceString(message, maxLen, "{white}",       "\x01", false);
        ReplaceString(message, maxLen, "{darkred}",     "\x02", false);
        ReplaceString(message, maxLen, "{pink}",        "\x03", false);
        ReplaceString(message, maxLen, "{green}",       "\x04", false);
        ReplaceString(message, maxLen, "{lime}",        "\x05", false);
        ReplaceString(message, maxLen, "{yellow}",      "\x05", false);
        ReplaceString(message, maxLen, "{lightgreen}",  "\x06", false);
        ReplaceString(message, maxLen, "{lightred}",    "\x07", false);
        ReplaceString(message, maxLen, "{red}",         "\x07", false);
        ReplaceString(message, maxLen, "{gray}",        "\x08", false);
        ReplaceString(message, maxLen, "{grey}",        "\x08", false);
        ReplaceString(message, maxLen, "{olive}",       "\x09", false);
        ReplaceString(message, maxLen, "{orange}",      "\x10", false);
        ReplaceString(message, maxLen, "{silver}",      "\x0A", false);
        ReplaceString(message, maxLen, "{lightblue}",   "\x0B", false);
        ReplaceString(message, maxLen, "{blue}",        "\x0C", false);
        ReplaceString(message, maxLen, "{purple}",      "\x0E", false);
        ReplaceString(message, maxLen, "{darkorange}",  "\x0F", false);
    }
}

stock void RemoveAllColors(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{normal}",      "", false);
    ReplaceString(message, maxLen, "{default}",     "", false);
    ReplaceString(message, maxLen, "{teamcolor}",   "", false);
    ReplaceString(message, maxLen, "{white}",       "", false);
    ReplaceString(message, maxLen, "{darkred}",     "", false);
    ReplaceString(message, maxLen, "{pink}",        "", false);
    ReplaceString(message, maxLen, "{green}",       "", false);
    ReplaceString(message, maxLen, "{lime}",        "", false);
    ReplaceString(message, maxLen, "{yellow}",      "", false);
    ReplaceString(message, maxLen, "{lightgreen}",  "", false);
    ReplaceString(message, maxLen, "{lightred}",    "", false);
    ReplaceString(message, maxLen, "{red}",         "", false);
    ReplaceString(message, maxLen, "{gray}",        "", false);
    ReplaceString(message, maxLen, "{grey}",        "", false);
    ReplaceString(message, maxLen, "{olive}",       "", false);
    ReplaceString(message, maxLen, "{orange}",      "", false);
    ReplaceString(message, maxLen, "{silver}",      "", false);
    ReplaceString(message, maxLen, "{lightblue}",   "", false);
    ReplaceString(message, maxLen, "{blue}",        "", false);
    ReplaceString(message, maxLen, "{purple}",      "", false);
    ReplaceString(message, maxLen, "{darkorange}",  "", false);
    ReplaceString(message, maxLen, "\x01",          "", false);
    ReplaceString(message, maxLen, "\x02",          "", false);
    ReplaceString(message, maxLen, "\x03",          "", false);
    ReplaceString(message, maxLen, "\x04",          "", false);
    ReplaceString(message, maxLen, "\x05",          "", false);
    ReplaceString(message, maxLen, "\x06",          "", false);
    ReplaceString(message, maxLen, "\x07",          "", false);
    ReplaceString(message, maxLen, "\x08",          "", false);
    ReplaceString(message, maxLen, "\x09",          "", false);
    ReplaceString(message, maxLen, "\x10",          "", false);
    ReplaceString(message, maxLen, "\x0A",          "", false);
    ReplaceString(message, maxLen, "\x0B",          "", false);
    ReplaceString(message, maxLen, "\x0C",          "", false);
    ReplaceString(message, maxLen, "\x0D",          "", false);
    ReplaceString(message, maxLen, "\x0E",          "", false);
    ReplaceString(message, maxLen, "\x0F",          "", false);
}

stock void SMUtils_SayText2(int client, const char[] msg)
{
    if(UMType == UM_Protobuf)
    {
        Protobuf SayText2 = view_as<Protobuf>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        SayText2.SetInt("ent_idx", 0);
        SayText2.SetBool("chat", SkipNextChatCS ? false : ChatConSnd);
        SayText2.SetString("msg_name", msg);
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        SayText2.AddString("params", "");
        EndMessage();
    }
    else
    {
        BfWrite SayText = view_as<BfWrite>(StartMessageOne("SayText", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        SayText.WriteByte(0);
        SayText.WriteByte(true);
        SayText.WriteString(msg);
        EndMessage();
    }
}


/**************************
            Hint
**************************/
stock void Hint(int client, const char[] buffer, any ...)
{
    char msg[256];
    SetGlobalTransTarget(client);
    VFormat(msg, 256, buffer, 3);
    
    SMUtils_Hint(client, msg);

    SetGlobalTransTarget(LANG_SERVER);
}

stock void HintAll(const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 2);

    if(UMType == UM_Protobuf)
    {
        Protobuf HintText = view_as<Protobuf>(StartMessageAll("HintText", USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        HintText.SetString("text", msg);
        EndMessage();
    }
    else
    {
        BfWrite HintText = view_as<BfWrite>(StartMessageAll("HintText", USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        HintText.WriteString(msg);
        EndMessage();
    }
}

stock void HintEx(int[] clients, int numClients, const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 3);

    if(UMType == UM_Protobuf)
    {
        Protobuf HintText = view_as<Protobuf>(StartMessage("HintText", clients, numClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        HintText.SetString("text", msg);
        EndMessage();
    }
    else
    {
        BfWrite HintText = view_as<BfWrite>(StartMessage("HintText", clients, numClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        HintText.WriteString(msg);
        EndMessage();
    }
}

stock void tHintAll(const char[] buffer, any ...)
{
    char msg[256];
    for(int client = 1; client <= MaxClients; ++client)
        if(ClientIsValid(client))
        {
            SetGlobalTransTarget(client);
            VFormat(msg, 256, buffer, 2);

            SMUtils_Hint(client, msg);
        }

    SetGlobalTransTarget(LANG_SERVER);
}

stock void SMUtils_Hint(int client, const char[] msg)
{
    if(UMType == UM_Protobuf)
    {
        Protobuf HintText = view_as<Protobuf>(StartMessageOne("HintText", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        HintText.SetString("text", msg);
        EndMessage();
    }
    else
    {
        BfWrite HintText = view_as<BfWrite>(StartMessageOne("HintText", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        HintText.WriteString(msg);
        EndMessage();
    }
}

/**************************
            TextMsg
**************************/
#define HUD_PRINTNOTIFY   1 
#define HUD_PRINTCONSOLE  2 
#define HUD_PRINTTALK     3 
#define HUD_PRINTCENTER   4 
static int TextMsgDest = HUD_PRINTCENTER;

stock void SMUtils_SetTextDest(int val)
{
    TextMsgDest = val;
}

stock void Text(int client, const char[] buffer, any ...)
{
    char msg[256];
    SetGlobalTransTarget(client);
    VFormat(msg, 256, buffer, 3);

    SMUtils_Text(client, msg);

    SetGlobalTransTarget(LANG_SERVER);
}

stock void TextAll(const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 2);

    if(UMType == UM_Protobuf)
    {
        Protobuf TextMsg = view_as<Protobuf>(StartMessageAll("TextMsg", USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        TextMsg.SetInt("msg_dst", TextMsgDest); 
        TextMsg.AddString("params", msg);
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        EndMessage();
    }
    else
    {
        BfWrite TextMsg = view_as<BfWrite>(StartMessageAll("TextMsg", USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        TextMsg.WriteByte(TextMsgDest); 
        TextMsg.WriteString(msg);
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        EndMessage();
    }
}

stock void TextEx(int[] clients, int numClients, const char[] buffer, any ...)
{
    char msg[256];
    VFormat(msg, 256, buffer, 3);

    if(UMType == UM_Protobuf)
    {
        Protobuf TextMsg = view_as<Protobuf>(StartMessage("TextMsg", clients, numClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        TextMsg.SetInt("msg_dst", TextMsgDest); 
        TextMsg.AddString("params", msg);
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        EndMessage();
    }
    else
    {
        BfWrite TextMsg = view_as<BfWrite>(StartMessage("TextMsg", clients, numClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        TextMsg.WriteByte(TextMsgDest); 
        TextMsg.WriteString(msg);
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        EndMessage();
    }
}

stock void tTextAll(const char[] buffer, any ...)
{
    char msg[256];
    for(int client = 1; client <= MaxClients; ++client)
        if(ClientIsValid(client))
        {
            SetGlobalTransTarget(client);
            VFormat(msg, 256, buffer, 2);

            SMUtils_Text(client, msg);
        }

    SetGlobalTransTarget(LANG_SERVER);
}

stock void SMUtils_Text(int client, const char[] msg)
{
    if(UMType == UM_Protobuf)
    {
        Protobuf TextMsg = view_as<Protobuf>(StartMessageOne("TextMsg", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        TextMsg.SetInt("msg_dst", TextMsgDest); 
        TextMsg.AddString("params", msg);
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        TextMsg.AddString("params", "");
        EndMessage();
    }
    else
    {
        BfWrite TextMsg = view_as<BfWrite>(StartMessageOne("TextMsg", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        TextMsg.WriteByte(TextMsgDest); 
        TextMsg.WriteString(msg);
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        TextMsg.WriteString("");
        EndMessage();
    }
}


/**************************
        MissionHint
**************************/
enum InstructorHud_Icon
{
    Icon_bulb = 0,
    Icon_caution,
    Icon_alert,
    Icon_alert_red,
    Icon_tip,
    Icon_skull,
    Icon_no,
    Icon_run,
    Icon_interact,
    Icon_button,
    Icon_door,
    Icon_arrow_plain,
    Icon_arrow_plain_white_dn,
    Icon_arrow_plain_white_up,
    Icon_arrow_up,
    Icon_arrow_right,
    Icon_fire,
    Icon_present
};

static char InstructorHud_Icon_String[InstructorHud_Icon][32] =
{
    "icon_bulb",
    "icon_caution",
    "icon_alert",
    "icon_alert_red",
    "icon_tip",
    "icon_skull",
    "icon_no",
    "icon_run",
    "icon_interact",
    "icon_button",
    "icon_door",
    "icon_arrow_plain",
    "icon_arrow_plain_white_dn",
    "icon_arrow_plain_white_up",
    "icon_arrow_up",
    "icon_arrow_right",
    "icon_fire",
    "icon_present"
};

//https://developer.valvesoftware.com/wiki/Env_instructor_hint
methodmap InstructorHud < Event
{
    property int target {
        public get () { return this.GetInt("hint_target", 0); }
        public set (int val) { this.SetInt("hint_target", val); }
    }
    
    property int flags {
        public get () { return this.GetInt("hint_flags", 0); }
        public set (int val) { this.SetInt("hint_flags", val); }
    }
    
    property int activator_userid {
        public get () { return this.GetInt("hint_activator_userid", 0); }
        public set (int val) { this.SetInt("hint_activator_userid", val); }
    }

    // true = follow, false = hold on hud
    property bool positioning {
        public get () { return this.GetBool("hint_static", true); }
        public set (bool val) { this.SetBool("hint_static", val); }
    }
    
    // true = end immed on nodraw, false = yes
    property bool invisible { 
        public get () { return this.GetBool("hint_allow_nodraw_target", true); }
        public set (bool val) { this.SetBool("hint_allow_nodraw_target", val); }
    }

    // true = no, false = show when occluded
    property bool forcecaption { 
        public get () { return this.GetBool("hint_forcecaption", false); }
        public set (bool val) { this.SetBool("hint_forcecaption", val); }
    }
    
    property InstructorHud_Icon icon_onscreen { 
        public get ()
        {
            char iconname[32];
            this.GetString("hint_icon_onscreen", iconname, 32);
            for(int i = 0; i < view_as<int>(InstructorHud_Icon); ++i)
                if(strcmp(iconname, InstructorHud_Icon_String[view_as<InstructorHud_Icon>(i)]) == 0)
                    return view_as<InstructorHud_Icon>(i);
            return Icon_bulb;
        }
        public set (InstructorHud_Icon icon) { this.SetString("hint_icon_onscreen", InstructorHud_Icon_String[icon]); }
    }
    
    property InstructorHud_Icon icon_offscreen { 
        public get ()
        {
            char iconname[32];
            this.GetString("hint_icon_offscreen", iconname, 32);
            for(int i = 0; i < view_as<int>(InstructorHud_Icon); ++i)
                if(strcmp(iconname, InstructorHud_Icon_String[view_as<InstructorHud_Icon>(i)]) == 0)
                    return view_as<InstructorHud_Icon>(i);
            return Icon_bulb;
        }
        public set (InstructorHud_Icon icon) { this.SetString("hint_icon_offscreen", InstructorHud_Icon_String[icon]); }
    }
    
    // true = don`t show, false = show;
    property bool show_offscreen {
        public get () { return this.GetBool("hint_nooffscreen", false); }
        public set (bool val) { this.SetBool("hint_nooffscreen", val); }
    }
    
    property float range {
        public get () { return this.GetFloat("hint_range", 1000.0); }
        public set (float val) { this.SetFloat("hint_nooffscreen", val); }
    }
    
    property float timeout {
        public get () { return this.GetFloat("hint_timeout", 1.0); }
        public set (float val) { this.SetFloat("hint_timeout", val); }
    }
    
    property float offset {
        public get () { return this.GetFloat("hint_icon_offset", 0.0); }
        public set (float val) { this.SetFloat("hint_icon_offset", val); }
    }
    
    property int pulseoption {
        public get () { return this.GetInt("hint_pulseoption", 0); }
        public set (int val) { this.SetInt("hint_pulseoption", val); }
    }
    
    property int alphaoption {
        public get () { return this.GetInt("hint_alphaoption", 0); }
        public set (int val) { this.SetInt("hint_alphaoption", val); }
    }
    
    // 0 = no, 1 = Narrow, 2 = Wide
    property int shakeoption {
        public get () { return this.GetInt("hint_shakeoption", 0); }
        public set (int val) { this.SetInt("hint_shakeoption", val); }
    }
    
    public void color(int r, int g, int b)
    {
        char clr[32];
        FormatEx(clr, 32, "%d %d %d", r, g, b);
        this.SetString("hint_color", clr);
    }

    public InstructorHud(const char[] name = "", int target = 0)
    {
        Event e = CreateEvent("instructor_server_hint_create", true);
        if(e == null)
            ThrowNativeError(SP_ERROR_NATIVE, "Create instructor_server_hint_create failed -> event is null.");

        e.SetBool("hint_local_player_only", true);

        e.SetInt("hint_flags", 0);
        e.SetInt("hint_activator_userid", 0);
        e.SetInt("hint_target", target);

        if(name[0] == 0)
        {
            e.SetString("hint_name", name);
            e.SetString("hint_replace_key", name);
        }
        else
        {
            char buffer[32];
            RandomString(buffer, 32);
            e.SetString("hint_name", buffer);
            e.SetString("hint_replace_key", buffer);
        }

        return view_as<InstructorHud>(e);
    }
    
    public void EasyInit()
    {
        this.color(57, 197, 187);
        this.positioning = false;
        this.invisible = true;
        this.forcecaption = false;
        this.show_offscreen = false;
        this.range = 1000.0;
        this.offset = 1.0;
        this.pulseoption = 0;
        this.alphaoption = 0;
        this.shakeoption = 0;
    }

    public void Destroy()
    {
        delete view_as<Event>(this);
    }

    public void Display(int client, const char[] buffer, any ...)
    {
        char caption[256];
        VFormat(caption, 256, buffer, 3);
        this.activator_userid = GetClientUserId(client);
        this.SetString("hint_caption", caption);
        this.SetString("hint_activator_caption", caption);
        this.FireToClient(client);
        this.activator_userid = 0;
    }

    public void DisplayAll(const char[] buffer, any ...)
    {
        char caption[256];
        VFormat(caption, 256, buffer, 2);
        this.SetString("hint_caption", caption);
        this.SetString("hint_activator_caption", caption);
        this.Fire();
    }

    public void tDisplay(int client, const char[] buffer, any ...)
    {
        SetGlobalTransTarget(client);
        char caption[256];
        VFormat(caption, 256, buffer, 3);
        this.activator_userid = GetClientUserId(client);
        this.SetString("hint_caption", caption);
        this.SetString("hint_activator_caption", caption);
        this.FireToClient(client);
        this.activator_userid = 0;
        SetGlobalTransTarget(LANG_SERVER);
    }
    
    public void tDisplayAll(const char[] buffer, any ...)
    {
        char caption[256];
        for(int client = 1; client <= MaxClients; ++client)
            if(ClientIsValid(client))
            {
                SetGlobalTransTarget(client);
                VFormat(caption, 256, buffer, 2);
                this.activator_userid = GetClientUserId(client);
                this.SetString("hint_caption", caption);
                this.SetString("hint_activator_caption", caption);
                this.FireToClient(client);
                
            }
        this.activator_userid = 0;
        SetGlobalTransTarget(LANG_SERVER);
    }
}

stock void EasyMissionHint(int client, float holdtime, InstructorHud_Icon icon, int r, int g, int b, const char[] caption, any ...)
{
    InstructorHud hint = new InstructorHud("");
    hint.EasyInit();
    hint.color(r, g, b);
    hint.timeout = holdtime;
    hint.icon_onscreen = icon;
    char msg[256];
    VFormat(msg, 256, caption, 8);
    hint.Display(client, msg);
    hint.Destroy();
}

stock void EasyMissionHintAll(float holdtime, InstructorHud_Icon icon, int r, int g, int b, const char[] caption, any ...)
{
    InstructorHud hint = new InstructorHud("");
    hint.EasyInit();
    hint.color(r, g, b);
    hint.timeout = holdtime;
    hint.icon_onscreen = icon;
    char msg[256];
    VFormat(msg, 256, caption, 7);
    hint.DisplayAll(msg);
    hint.Destroy();
}


/**************************
            Sound
**************************/
stock void PrepareSound(const char[] sound)
{
    static int table_download = INVALID_STRING_TABLE;
    static int table_soundpre = INVALID_STRING_TABLE;

    if(table_download == INVALID_STRING_TABLE)
        table_download = FindStringTable("downloadables");

    if(table_soundpre == INVALID_STRING_TABLE)
        table_soundpre = FindStringTable("soundprecache");

    char buffer[256];
    bool prevls;  //Previous lock state.

    // precache
    FormatEx(buffer, 256, "*%s", sound);
    prevls = LockStringTables(false);
    AddToStringTable(table_soundpre, buffer);
    LockStringTables(prevls);
    
    // downloader
    FormatEx(buffer, 256, "sound/%s", sound);
    prevls = LockStringTables(false);
    AddToStringTable(table_download, buffer);
    LockStringTables(prevls);
}

stock void EmitSoundEx(const int[] clients, int numClients, const char[] sample, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true, float soundtime = 0.0)
{
    char sound[256];
    FormatEx(sound, 256, "*%s", sample);
    EmitSound(clients, numClients, sound, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
}

stock void EmitSoundOne(int client, const char[] sample, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true, float soundtime = 0.0)
{
    char sound[256];
    FormatEx(sound, 256, "*%s", sample);
    EmitSoundToClient(client, sound, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
}

stock void EmitSoundAll(const char[] sample, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true, float soundtime = 0.0)
{
    char sound[256];
    FormatEx(sound, 256, "*%s", sample);
    EmitSoundToAll(sound, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
}


/**************************
            Weapon
**************************/
stock int GetWeaponClassname(int weapon, int index = -1, char[] classname, int maxLen)
{
    if(!GetEdictClassname(weapon, classname, maxLen))
        return -1;

    if(index == -1)
        index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

    switch(index)
    {
        case 60 : return strcopy(classname, maxLen, "weapon_m4a1_silencer");
        case 61 : return strcopy(classname, maxLen, "weapon_usp_silencer");
        case 63 : return strcopy(classname, maxLen, "weapon_cz75a");
        case 64 : return strcopy(classname, maxLen, "weapon_revolver");
        case 500: return strcopy(classname, maxLen, "weapon_bayonet");
        case 506: return strcopy(classname, maxLen, "weapon_knife_gut");
        case 505: return strcopy(classname, maxLen, "weapon_knife_flip");
        case 508: return strcopy(classname, maxLen, "weapon_knife_m9_bayonet");
        case 507: return strcopy(classname, maxLen, "weapon_knife_karambit");
        case 509: return strcopy(classname, maxLen, "weapon_knife_tactical");
        case 515: return strcopy(classname, maxLen, "weapon_knife_butterfly");
        case 512: return strcopy(classname, maxLen, "weapon_knife_falchion");
        case 516: return strcopy(classname, maxLen, "weapon_knife_push");
        case 514: return strcopy(classname, maxLen, "weapon_knife_survival_bowie");
    }
    
    return strlen(classname);
}

stock int GetPlayerWeaponEntity(int client, const char[] weapons)
{
    int weapon = -1;
    int m_hMyWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for(int offset = 0; offset < m_hMyWeapons; offset++)
    {
        weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", offset);
        if(weapon > MaxClients)
            return weapon;
    }

    return -1;
}

stock bool RemoveWeaponByClassname(int client, const char[] weapons)
{
    int weapon = GetPlayerWeaponEntity(client, weapons);
    return (weapon != -1) ? RemoveWeapon(client, weapon) : false;
}

stock bool RemoveWeapon(int client, int weapon)
{
    if(!RemovePlayerItem(client, weapon))
        return false;

    int m_hWeaponWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
    if(IsValidEdict(m_hWeaponWorldModel))
        AcceptEntityInput(m_hWeaponWorldModel, "Kill");

    if(weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);

    AcceptEntityInput(weapon, "Kill");

    return true;
}

stock void SetWeaponClip(int weapon, int ammo)
{
    if(!HasEntProp(weapon, Prop_Send, "m_iClip1"))
        ThrowNativeError(SP_ERROR_PARAM, "Weapon %d has not m_iClip1 Props.", weapon);

    SetEntProp(weapon, Prop_Send, "m_iClip1", ammo, 4, 0);
}

stock void SetWeaponAmmo(int weapon, int ammo)
{
    if(!HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
        ThrowNativeError(SP_ERROR_PARAM, "Weapon %d has not m_iPrimaryReserveAmmoCount Props.", weapon);

    SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
}

stock void SetWeaponAmmoEx(int client, int weapon, int ammo)
{
    int amtype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if(amtype == -1)
        ThrowError("Weapon %d -> m_iPrimaryAmmoType is -1.", weapon);

    SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, amtype);
}

stock void StripWeapon(int client, bool suit = false)
{
    int stripper = CreateEntityByName("player_weaponstrip"); 
    if(stripper == -1)
        ThrowNativeError(SP_ERROR_NATIVE, "Create player_weaponstrip failed.");
    
    AcceptEntityInput(stripper, !suit ? "Strip" : "StripWeaponsAndSuit", client);
    AcceptEntityInput(stripper, "Kill");
}

stock void StripWeaponAll()
{
    int stripper = CreateEntityByName("game_player_equip");
    if(stripper == -1)
        ThrowNativeError(SP_ERROR_NATIVE, "Create game_player_equip failed.");

    DispatchKeyValue(stripper, "spawnflags", "2");

    AcceptEntityInput(stripper, "TriggerForAllPlayers");
    AcceptEntityInput(stripper, "Kill");
}

stock int GetClientActiveWeapon(int client)
{
    if(!ClientIsAlive(client))
        return -1;

    return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}


/**************************
            Overlay
**************************/
stock void PrepareOverlay(const char[] overlay)
{
    static int table_download = INVALID_STRING_TABLE;
    if(table_download == INVALID_STRING_TABLE)
        table_download = FindStringTable("downloadables");
    
    bool prev;
    char path[256];
    
    FormatEx(path, 256, "%s.vmt", overlay);
    PrecacheDecal(path, true);
    
    FormatEx(path, 256, "materials/%s.vmt", overlay);
    prev = LockStringTables(false);
    AddToStringTable(table_download, path);
    LockStringTables(prev);

    FormatEx(path, 256, "%s.vtf", overlay);
    PrecacheDecal(path, true);

    FormatEx(path, 256, "materials/%s.vtf", overlay);
    prev = LockStringTables(false);
    AddToStringTable(table_download, path);
    LockStringTables(prev);
}

stock void Overlay(int client, const char[] overlay, float holdtime = 0.0)
{
    ClientCommand(client, "r_screenoverlay \"%s.vtf\"", overlay);

    if(holdtime >= 0.0)
        CreateTimer(holdtime, Timer_RemoveOverlay_smutils_overlay, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

stock void OverlayAll(const char[] overlay, float holdtime = 0.0)
{
    for(int client = 1; client <= MaxClients; ++client)
        if(ClientIsValid(client))
            ClientCommand(client, "r_screenoverlay \"%s.vtf\"", overlay);

    if(holdtime >= 0.0)
        CreateTimer(holdtime, Timer_RemoveOverlay_smutils_overlay, -1, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RemoveOverlay_smutils_overlay(Handle timer, int userid)
{
    if(userid == -1)
    {
        for(int client = 1; client <= MaxClients; ++client)
            if(ClientIsValid(client))
                ClientCommand(client, "r_screenoverlay \"\"");
            
        return Plugin_Stop;
    }
    
    int client = GetClientOfUserId(userid);

    if(ClientIsValid(client))
        ClientCommand(client, "r_screenoverlay \"\"");

    return Plugin_Stop;
}


/**************************
            Entity
**************************/
stock bool SetEntityParent(int child, int parent)
{
    SetVariantString("!activator");
    return AcceptEntityInput(child, "SetParent", parent, child, 0);
}

stock bool SetEntityParentEx(int child, int parent, const char[] attchment, const float offset[3] = {0.0, 0.0, 0.0})
{
    if(!SetEntityParent(child, parent))
        return false;

    SetVariantString(attchment);
    
    if(offset[0] != 0.0 || offset[1] != 0.0 || offset[2] != 0.0)
        return AcceptEntityInput(child, "SetParentAttachment", parent, child);

    float fPos[3];
    GetEntPropVector(parent, Prop_Send, "m_vecOrigin", fPos);
    AddVectors(fPos, offset, fPos);
    TeleportEntity(child, fPos, NULL_VECTOR, NULL_VECTOR);

    return AcceptEntityInput(child, "SetParentAttachmentMaintainOffset", parent, child);
}

stock bool SelfKillEntity(int entity, float delay = 0.1)
{
    if(!IsValidEntity(entity))
        return true;

    char input[128];
    FormatEx(input, 128, "OnUser4 !self:Kill::%.2f:1", delay);
    SetVariantString(input);
    return (AcceptEntityInput(entity, "AddOutput") && AcceptEntityInput(entity, "FireUser4"));
}

stock bool SelfKillEntityEx(int entity, float delay = 0.0)
{
    if(!IsValidEntity(entity))
        return true;

    char input[128];
    FormatEx(input, 128, "OnUser4 !self:KillHierarchy::%.2f:1", delay);
    SetVariantString(input);
    return (AcceptEntityInput(entity, "AddOutput") && AcceptEntityInput(entity, "FireUser4"));
}

stock void RemoveEntityEx(int entity, float delay = 0.0) // 0.0 = 1 frame delay
{
    if(!IsValidEntity(entity))
        return;

    if(delay < 0.0)
    {
        AcceptEntityInput(entity, "Kill");
        return;
    }

    CreateTimer(delay, Timer_DestroyEntity_smutils_removeentity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

stock void RemoveEdictEx(int edict, float delay = 0.0)
{
    if(!IsValidEdict(edict))
        return;

    if(delay < 0.0)
    {
        RemoveEdict(edict);
        AcceptEntityInput(edict, "Kill");
        return;
    }

    CreateTimer(delay, Timer_DestroyEdict_smutils_removeedice, EntIndexToEntRef(edict), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DestroyEntity_smutils_removeentity(Handle timer, int entRef)
{
    int entity = EntRefToEntIndex(entRef);
    if(IsValidEntity(entity))
    {
        if(!AcceptEntityInput(entity, "Kill"))
            LogError("can not kill entity %d", entity);
    }

    return Plugin_Stop;
}

public Action Timer_DestroyEdict_smutils_removeedice(Handle timer, int edictRef)
{
    int edict = EntRefToEntIndex(edictRef);
    if(IsValidEdict(edict))
    {
        RemoveEdict(edict);
        if(!AcceptEntityInput(edict, "Kill"))
            LogError("can not kill edict %d", edict);
    }

    return Plugin_Stop;
}

stock bool SetTextureIndex(int entity, int index, float delay = 0.1)
{
    char targetname[32];
    GetEntityTargetName(entity, targetname, 32);
    if(strlen(targetname) < 3)
    {
        RandomString(targetname, 32);
        DispatchKeyValue(entity, "targetname", targetname);
    }
    
    int toggle = CreateEntityByName("env_texturetoggle");
    if(toggle == -1)
        return false;
    
    DispatchKeyValue(toggle, "target", targetname);
    DispatchSpawn(toggle);
    
    if(!SelfKillEntity(toggle, delay + 0.5))
        return false;

    char input[32];
    FormatEx(input, 32, "OnUser3 !self:SetTextureIndex:%d:%.2f:1", index, delay);
    SetVariantString(input);
    return (AcceptEntityInput(entity, "AddOutput") && AcceptEntityInput(entity, "FireUser3"));
}

stock int GetEntityHammerID(int entity)
{
    return GetEntProp(entity, Prop_Data, "m_iHammerID");
}

stock int GetEntityTargetName(int entity, char[] buffer, int size)
{
    return GetEntPropString(entity, Prop_Data, "m_iName", buffer, size);
}

stock int GetEntityParentName(int entity, char[] buffer, int size)
{
    return GetEntPropString(entity, Prop_Data, "m_iParent", buffer, size);
}


/**************************
            Misc
**************************/
stock void FreeHandle(Handle &hndl)
{
    if(hndl != INVALID_HANDLE)
    {
        CloseHandle(hndl);
        hndl = INVALID_HANDLE;
    }
}

stock void StopTimer(Handle &timer)
{
    if(timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }
}

stock int RandomInt(int min = 0, int max = 2147483647)
{
    int random = GetURandomInt();

    if(random == 0)
        random++;

    return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock float RandomFloat(float min = 0.0, float max = 5201314.0)
{
    return (GetURandomFloat() * (max  - min)) + min;
}

stock void RandomString(char[] buffer, int maxLen)
{
    // terminator
    maxLen--;

    char random[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234556789";
    int randlen = strlen(random);

    int n = 0;
    int c = 0;

    while(n < maxLen)
    {
        if(random[0] == '\0')
        {
            c = GetRandomInt(33, 126);
            buffer[n] = c;
        }
        else
        {
            c = GetRandomInt(0, randlen);
            buffer[n] = random[c];
        }

        n++;
    }

    buffer[maxLen] = '\0';
}

stock void RandomStringEx(const char[] random, char[] buffer, int maxLen)
{
    maxLen--;
    
    int randlen = strlen(random);

    int n = 0;
    int c = 0;

    while(n < maxLen)
    {
        c = GetRandomInt(0, randlen);
        buffer[n++] = random[c];
    }

    buffer[maxLen] = '\0';
}

stock void StringToLower(const char[] input, char[] output, int size)
{
    size--;
    output[0] = '\0';

    int x = 0;
    while(input[x] != '\0' && x < size)
    {
        output[x] = CharToLower(input[x]);
        x++;
    }

    output[x] = '\0';
}

stock void StringToUpper(const char[] input, char[] output, int size)
{
    size--;
    output[0] = '\0';

    int x = 0;
    while(input[x] != '\0' && x < size)
    {
        output[x] = CharToUpper(input[x]);
        x++;
    }

    output[x] = '\0';
}
