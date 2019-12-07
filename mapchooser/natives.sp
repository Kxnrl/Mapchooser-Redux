enum struct Forwards
{
    GlobalForward m_NominationsReset;
    GlobalForward m_MapVoteStarted;
    GlobalForward m_MapVoteEnd;
    GlobalForward m_MapDataLoaded;
    GlobalForward m_MapVotePoolChanged;
}

static Forwards g_Forward;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (!CleanPlugin())
    {
        strcopy(error, err_max, "can not clean files.");
        return APLRes_Failure;
    }

    RegPluginLibrary("mapchooser");

    CreateNative("NominateMap",             Native_NominateMap);
    CreateNative("RemoveNominationByMap",   Native_RemoveNominationByMap);
    CreateNative("RemoveNominationByOwner", Native_RemoveNominationByOwner);
    CreateNative("InitiateMapChooserVote",  Native_InitiateVote);
    CreateNative("CanMapChooserStartVote",  Native_CanVoteStart);
    CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
    CreateNative("GetExcludeMapList",       Native_GetExcludeMapList);
    CreateNative("GetNominatedMapList",     Native_GetNominatedMapList);
    CreateNative("EndOfMapVoteEnabled",     Native_EndOfMapVoteEnabled);
    CreateNative("CanNominate",             Native_CanNominate);
    CreateNative("GetMapData",              Native_GetMapData);

    MarkNativeAsOptional("Store_GetClientCredits");
    MarkNativeAsOptional("Store_SetClientCredits");

    MarkNativeAsOptional("MG_Shop_GetClientMoney");
    MarkNativeAsOptional("MG_Shop_ClientEarnMoney");
    MarkNativeAsOptional("MG_Shop_ClientCostMoney");

    return APLRes_Success;
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

void Natives_OnPluginStart()
{
    g_Forward.m_NominationsReset   = new GlobalForward("OnNominationRemoved",    ET_Ignore, Param_String, Param_Cell, Param_Cell);
    g_Forward.m_MapVoteStarted     = new GlobalForward("OnMapVoteStarted",       ET_Ignore);
    g_Forward.m_MapVoteEnd         = new GlobalForward("OnMapVoteEnd",           ET_Ignore, Param_String);
    g_Forward.m_MapDataLoaded      = new GlobalForward("OnMapDataLoaded",        ET_Ignore);
    g_Forward.m_MapVotePoolChanged = new GlobalForward("OnMapVotePoolChanged",   ET_Ignore);
}

void Call_NominationsReset(const char[] map, int _cell, bool _bool)
{
    Call_StartForward(g_Forward.m_NominationsReset);
    Call_PushString(map);
    Call_PushCell(_cell);
    Call_PushCell(_bool);
    Call_Finish();
}

void Call_MapVoteStarted()
{
    Call_StartForward(g_Forward.m_MapVoteStarted);
    Call_Finish();
}

void Call_MapVoteEnd(const char[] map)
{
    Call_StartForward(g_Forward.m_MapVoteEnd);
    Call_PushString(map);
    Call_Finish();
}

void Call_MapDataLoaded()
{
    Call_StartForward(g_Forward.m_MapDataLoaded);
    Call_Finish();
}

void Call_MapVotePoolChanged()
{
    Call_StartForward(g_Forward.m_MapVotePoolChanged);
    Call_Finish();
}

public any Native_RemoveNominationByMap(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);

    if (len <= 0)
      return false;
    
    char[] map = new char[len+1];
    GetNativeString(1, map, len+1);

    return InternalRemoveNominationByMap(map);
}

public any Native_NominateMap(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);

    if (len <= 0)
      return false;

    char[] map = new char[len+1];
    GetNativeString(1, map, len+1);

    return InternalNominateMap(map, GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
}

public any Native_IsWarningTimer(Handle plugin, int numParams)
{
    return g_bWarningInProgress;
}

public any Native_CanNominate(Handle plugin, int numParams)
{
    if (g_bHasVoteStarted)
        return CanNominate_No_VoteInProgress;
    
    if (g_bMapVoteCompleted)
        return CanNominate_No_VoteComplete;
    
    if (g_iNominateCount >= 5)
        return CanNominate_No_VoteFull;

    if (g_bPartyblock)
        return CanNominate_No_PartyBlock;

    return CanNominate_Yes;
}

public any Native_RemoveNominationByOwner(Handle plugin, int numParams)
{    
    return InternalRemoveNominationByOwner(GetNativeCell(1));
}

public any Native_InitiateVote(Handle plugin, int numParams)
{
    MapChange when = view_as<MapChange>(GetNativeCell(1));
    ArrayList maps = view_as<ArrayList>(GetNativeCell(2));

    LogAction(-1, -1, "Starting map vote because outside request");

    SetupWarningTimer(WarningType_Vote, when, maps);
}

public any Native_CanVoteStart(Handle plugin, int numParams)
{
    return CanVoteStart();    
}

public any Native_CheckVoteDone(Handle plugin, int numParams)
{
    return g_bMapVoteCompleted;
}

public any Native_GetExcludeMapList(Handle plugin, int numParams)
{
    GetCooldownMaps(view_as<ArrayList>(GetNativeCell(1)));
}

public any Native_GetNominatedMapList(Handle plugin, int numParams)
{
    ArrayList m_aNominations = view_as<ArrayList>(GetNativeCell(1));
    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));
        m_aNominations.PushArray(  n, sizeof(Nominations));
    }
}

public any Native_EndOfMapVoteEnabled(Handle plugin, int numParams)
{
    return true;
}
