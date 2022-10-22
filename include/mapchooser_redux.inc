#define MCR_VERSION "2.0.<commits>"

//credits: https://github.com/powerlord/sourcemod-mapchooser-extended
//credits: https://github.com/alliedmodders/sourcemod/blob/master/plugins/

#define VOTE_EXTEND             "##extend##"
#define VOTE_DONTCHANGE         "##dontchange##"
#define LINE_ONE                "##lineone##"
#define LINE_TWO                "##linetwo##"
#define LINE_SPACER             "##linespacer##"
#define FAILURE_TIMER_LENGTH    5
#define typeofdata              sizeof(MapData)
#define MAX_TIER                6

enum MapChange
{
    MapChange_Instant,
    MapChange_RoundEnd,
    MapChange_MapEnd,
};

enum CanNominateResult
{
    CanNominate_No_VoteFull,
    CanNominate_No_VoteInProgress,
    CanNominate_No_VoteComplete,
    CanNominate_No_PartyBlock,
    CanNominate_Yes
};

enum WarningType
{
    WarningType_Vote,
    WarningType_Revote,
    WarningType_Delay
};

enum NominateResult
{
    NominateResult_Added,
    NominateResult_Replaced,
    NominateResult_AlreadyInVote,
    NominateResult_InvalidMap,
    NominateResult_VoteFull,
    NominateResult_MinPlayers,
    NominateResult_MaxPlayers,
    NominateResult_NoCredits,
    NominateResult_AdminOnly,
    NominateResult_VIPOnly,
    NominateResult_CertainTimes,
    NominateResult_RecentlyPlayed,
    NominateResult_PartyBlock,
    NominateResult_PartyBlockDisabled,
    NominateResult_PartyBlockAdded,
    NominateResult_Reject
};

enum NominateResetReason_t
{
    NominateResetReason_Disconnect,
    NominateResetReason_Voted,
    NominateResetReason_PartyBlock,
    NominateResetReason_Replace,
    NominateResetReason_ForceFull,
    NominateResetReason_Remove,
    NominateResetReason_Refund
}

enum struct MapData
{
    // mapdata.kv
    char m_FileName[128];
    char m_Description[32];
    int  m_Tier;
    int  m_Price;
    int  m_PricePartyBlock;
    int  m_FileSize;
    int  m_MinPlayers;
    int  m_MaxPlayers;
    int  m_MaxCooldown;
    bool m_NominateOnly;
    bool m_VipOnly;
    bool m_AdminOnly;
    bool m_CertainTimes[24]; // 0-23
    float m_RefundRatio;

    // mappool.kv
    int  m_CooldownLeft;
    int  m_RecentlyPlayed;
}

enum struct Nominations
{
    char m_Map[128];
    int  m_Owner;
    int  m_Price;
    char m_OwnerName[32];
    char m_OwnerAuth[32];
}

forward void OnNominationRemoved(const char[] map, int client, bool partyblock, NominateResetReason_t reason);
forward void OnNominationVoted(const char[] map, const char[] name, const char[] auth);
forward void OnMapVoteStarted();
forward void OnMapVoteEnd(const char[] map, bool partyblock, int client);
forward void OnSetNextMapManually(const char[] map, int client);
forward void OnMapDataLoaded();
forward void OnMapVotePoolChanged();
forward bool OnNominateMap(const char[] map, int client, bool partyblock, bool replace);
forward void OnNominatedMap(const char[] map, int client, bool partyblock, bool replace);
forward bool OnNominatePrice(const char[] map, int client, int &price, bool partyblock);
forward bool OnClearMapCooldown(const char[] map, int client);
forward bool OnResetMapCooldown(const char[] map, int client);
forward bool OnNextMapListCreate(const char[] map);
forward bool OnSetNextMap(const char[] map, int client);

native CanNominateResult CanNominate();
native NominateResult NominateMap(const char[] map, bool force, int owner, bool partyblock = false);
native bool RemoveNominationByMap(const char[] map);
native bool RemoveNominationByOwner(int client);
native void InitiateMapChooserVote(MapChange when, ArrayList inputarray = null, WarningType type = WarningType_Vote);
native bool CanMapChooserStartVote();
native bool HasEndOfMapVoteFinished();
native bool EndOfMapVoteEnabled();
native bool GetMapData(const char[] map, any[] data, int size);
native void GetExcludeMapList(ArrayList array);
native void GetNominatedMapList(ArrayList array);
native int  GetPartyBlockOnwer();
native bool ForceSetNextMap(const char[] map, bool force = false, int client = -1);
native bool SetTierString(int tier, const char[] ts);
native void GetTierString(int tier, char[] ts, int len);
native bool IsWarningTimerRunning();
native int  GetMapExtendVoteRemaining();

stock bool IsClientVIP(int client)
{
    return CheckCommandAccess(client, "check_isclientvip", ADMFLAG_RESERVATION, false);
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "sm_cvar", ADMFLAG_CONVARS, false);
}

stock bool GetMapDesc(const char[] map, char[] buffer, int maxlen)
{
    MapData mapdata;
    if (GetMapData(map, mapdata, typeofdata))
    {
        strcopy(buffer, maxlen, mapdata.m_Description);
    }
    return false;
}

stock bool GetMapDescEx(const char[] map, char[] desc, int maxLen, bool includeName, bool includeTag, bool includePrice = false, bool includeTier = false)
{
    MapData mapdata;
    if (!GetMapData(map, mapdata, typeofdata))
        return false;

    strcopy(desc, maxLen, mapdata.m_Description);

    if (mapdata.m_Tier > 0 && includeTier)
    {
        char tier[32];
        GetTierString(mapdata.m_Tier, tier, 32);
        Format(desc, maxLen, "<%s>%s", tier, desc);
    }

    if (includeName)
    {
        if (includeTag)
        {
            Format(desc, maxLen, "%s%s%s\n%s", map, mapdata.m_VipOnly ? " [VIP]" : "", mapdata.m_AdminOnly ? " [ADMIN]" : "", desc);
        }
        else
        {
            Format(desc, maxLen, "%s\n%s", map, desc);
        }
    }
    else
    {
        if (includeTag)
        {
            Format(desc, maxLen, "%s%s", mapdata.m_VipOnly   ? "[VIP] "   : "", desc);
            Format(desc, maxLen, "%s%s", mapdata.m_AdminOnly ? "[ADMIN] " : "", desc);
        }
    }

    if (includePrice)
    {
        // ?
        Format(desc, maxLen, "%s [%d]", desc, mapdata.m_Price);
    }

    return true;
}

stock int GetMapPrice(const char[] map, bool recently = true, bool partyblock = false)
{
    MapData mapdata;
    if (!GetMapData(map, mapdata, typeofdata))
        return 100;

    if (partyblock)
        return mapdata.m_PricePartyBlock;

    int interval = FindConVar("mcr_rectplayed_interval").IntValue;

    if (recently && interval > -1)
    {
        int last = mapdata.m_RecentlyPlayed;
        int time = GetTime();
        int hour = (time - last) / 3600;
        if (hour < interval) //
        {
            return RoundFloat(mapdata.m_Price *= (1.0 + FindConVar("mcr_rectplayed_ltp_mtpl").FloatValue));
        }
    }

    return mapdata.m_Price;
}

stock bool GetMapPermission(const char[] map, bool &vip, bool &adm, int &min, int &max)
{
    MapData mapdata;
    if (!GetMapData(map, mapdata, typeofdata))
        return false;

    vip = mapdata.m_VipOnly;
    adm = mapdata.m_AdminOnly;
    min = mapdata.m_MinPlayers;
    max = mapdata.m_MaxPlayers;
    return true;
}

stock int GetMapCooldown(const char[] map)
{
    MapData mapdata;
    if (!GetMapData(map, mapdata, typeofdata))
        return 100;

    return mapdata.m_CooldownLeft;
}

stock bool IsNominated(const char[] map)
{
    ArrayList list = new ArrayList(sizeof(Nominations));
    GetNominatedMapList(list);
    for(int i = 0; i < list.Length; i++)
    {
        Nominations n;
        list.GetArray(i, n, sizeof(Nominations));
        if (strcmp(n.m_Map, map) == 0)
        {
            delete list;
            return true;
        }
    }
    delete list;
    return false;
}

stock bool GetNominated(const char[] map, Nominations n)
{
    ArrayList list = new ArrayList(sizeof(Nominations));
    GetNominatedMapList(list);

    for(int i = 0; i < list.Length; i++)
    {
        Nominations _n;
        list.GetArray(i, _n, sizeof(Nominations));
        if (strcmp(n.m_Map, map) == 0)
        {
            delete list;
            n = _n;
            return true;
        }
    }
    delete list;
    return false;
}