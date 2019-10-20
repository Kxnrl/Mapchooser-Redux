#define MCR_VERSION "1.7.<commits>"

#define VOTE_EXTEND             "##extend##"
#define VOTE_DONTCHANGE         "##dontchange##"
#define LINE_ONE                "##lineone##"
#define LINE_TWO                "##linetwo##"
#define LINE_SPACER             "##linespacer##"
#define FAILURE_TIMER_LENGTH    5

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
    CanNominate_Yes
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
    NominateResult_OnlyAdmin,
    NominateResult_OnlyVIP,
    NominateResult_RecentlyPlayed
};

KeyValues g_hKvMapData;

forward void OnNominationRemoved(const char[] map, int client);
forward void OnMapVoteStarted();
forward void OnMapVoteEnd(const char[] map);
forward void OnMapDataLoaded();

native CanNominateResult CanNominate();
native NominateResult NominateMap(const char[] map, bool force, int owner);
native bool RemoveNominationByMap(const char[] map);
native bool RemoveNominationByOwner(int client);
native void InitiateMapChooserVote(MapChange when, ArrayList inputarray);
native bool CanMapChooserStartVote();
native bool HasEndOfMapVoteFinished();
native void GetExcludeMapList(ArrayList array);
native void GetNominatedMapList(ArrayList maparray, ArrayList ownerarray);
native bool EndOfMapVoteEnabled();

// stocks
stock bool AddMapItem(Handle menu, const char[] map, bool includeTag, bool ori = false)
{
    if(!ori)
    {
        char szTrans[192];
        if(GetMapDesc(map, szTrans, 192, true, includeTag))
            return AddMenuItem(menu, map, szTrans);
    }

    return AddMenuItem(menu, map, map);
}

stock int GetMapPrice(const char[] map)
{
    if(g_hKvMapData == null)
        return 100;

    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return 100;

    int credits = g_hKvMapData.GetNum("price", 0);
    if (credits < 100)
        credits = 100;
    if (credits > 99999)
        credits = 99999;

    return credits;
}

stock bool GetMapDesc(const char[] map, char[] desc, int maxLen, bool includeName, bool includeTag, bool includePrice = false)
{
    if(g_hKvMapData == null)
        return false;

    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return false;

    g_hKvMapData.GetString("desc", desc, maxLen, map);

    if(includeName)
        Format(desc, maxLen, "%s\n%s", map, desc);

    if(includeTag)
    {
        Format(desc, maxLen, "%s%s", IsOnlyAdmin(map) ? "✪" : "", desc);
        Format(desc, maxLen, "%s%s", IsOnlyVIP(map) ? "♚" : "", desc);
        Format(desc, maxLen, "%s%s", IsNiceMap(map) ? "★" : "", desc);
    }

    if(includePrice)
        Format(desc, maxLen, "%s[%d]", desc, GetMapPrice(map));

    return true;
}

stock bool IsNiceMap(const char[] map)
{
    if(g_hKvMapData == null)
        return false;
    
    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return false;

    return (g_hKvMapData.GetNum("nice", 0) == 1);
}

stock bool IsBigMap(const char[] map)
{
    if(g_hKvMapData == null)
        return false;

    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return false;

    return (g_hKvMapData.GetNum("size", 0) > 149);
}

stock int GetMinPlayers(const char[] map)
{
    if(g_hKvMapData == null)
        return 0;
    
    g_hKvMapData.Rewind();
    
    if(!g_hKvMapData.JumpToKey(map, false))
        return 0;

    return g_hKvMapData.GetNum("minplayers", 0);
}

stock int GetMaxPlayers(const char[] map)
{
    if(g_hKvMapData == null)
        return 0;
    
    g_hKvMapData.Rewind();
    
    if(!g_hKvMapData.JumpToKey(map, false))
        return 0;
    
    return g_hKvMapData.GetNum("maxplayers", 0);
}

stock bool IsOnlyNomination(const char[] map)
{
    if(g_hKvMapData == null)
        return false;
    
    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return false;

    return (g_hKvMapData.GetNum("nominationonly", 0) == 1);
}

stock bool IsOnlyAdmin(const char[] map)
{
    if(g_hKvMapData == null)
        return false;
    
    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return false;

    return (g_hKvMapData.GetNum("adminonly", 0) == 1);
}

stock bool IsOnlyVIP(const char[] map)
{
    if(g_hKvMapData == null)
        return false;
    
    g_hKvMapData.Rewind();

    if(!g_hKvMapData.JumpToKey(map, false))
        return false;

    return (g_hKvMapData.GetNum("viponly", 0) == 1);
}

stock int UTIL_GetRandomInt(int min, int max)
{
    int random = GetURandomInt();
    
    if(random == 0)
        random++;

    return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock bool IsClientVIP(int client)
{
    return CheckCommandAccess(client, "check_isclientvip", ADMFLAG_RESERVATION, false);
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP, false);
}