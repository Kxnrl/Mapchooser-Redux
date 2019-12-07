#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public void OnPluginStart()
{
    char path[2][128], map[128];
    BuildPath(Path_SM, path[0], 128, "configs/mapdata.txt");
    BuildPath(Path_SM, path[1], 128, "configs/mapdata.kv");

    ArrayList maps = GetAllMapsName();
    KeyValues oldk = new KeyValues("MapData"); 
    KeyValues newk = new KeyValues("MapData");

    if (!oldk.ImportFromFile(path[0]))
        SetFailState("Failed to import from [%s]", path[0]);

    if (!newk.ImportFromFile(path[1]))
        SetFailState("Failed to import from [%s]", path[1]);

    for(int index = 0; index < maps.Length; index++)
    {
        oldk.Rewind();
        newk.Rewind();

        maps.GetString(index, map, 128);
        
        if (!oldk.JumpToKey(map, false))
        {
            LogMessage("Failed to jump from old: %s", map);
            continue;
        }

        if (!newk.JumpToKey(map, false))
        {
            LogMessage("Failed to jump from new: %s", map);
            continue;
        }

        char temp[128];
        oldk.GetString("Desc", temp, 128);
        Format(temp, 128, "%s %s", oldk.GetNum("Nice", 0) == 1 ? "*神图*" : "*咸鱼*", temp);
        newk.SetString("m_Description",   temp);
        newk.SetString("m_CertainTimes", "all");

        newk.SetNum("m_Price", oldk.GetNum("price", 1000));
        newk.SetNum("m_PricePartyBlock", oldk.GetNum("price", 1000) * 10);
        newk.SetNum("m_MinPlayers", oldk.GetNum("minplayers", 1000));
        newk.SetNum("m_MaxPlayers", oldk.GetNum("maxplayers", 1000));
        newk.SetNum("m_MaxCooldown", 100);
        newk.SetNum("m_NominateOnly", oldk.GetNum("OnlyNomination", 0));
        newk.SetNum("m_VipOnly", oldk.GetNum("OnlyAdmin", 0));
        newk.SetNum("m_AdminOnly", oldk.GetNum("OnlyVIP", 0));
    }

    oldk.Rewind();
    newk.Rewind();

    newk.ExportToFile(path[1]);
}

stock ArrayList GetAllMapsName()
{
    ArrayList maps = new ArrayList(ByteCountToCells(128));

    DirectoryListing dir = OpenDirectory("maps");
    if (dir == null)
    {
        LogError("GetAllMapsName -> Failed to open maps.");
        return maps;
    }

    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if (type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;

        int c = FindCharInString(map, '.', true);
        map[c] = '\0';

        if (!IsMapValid(map))
        {
            LogError("GetAllMapsName -> %s is invalid map.", map);
            continue;
        }

        maps.PushString(map);
    }

    delete dir;
    return maps;
}