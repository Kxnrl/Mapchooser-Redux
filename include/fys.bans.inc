#if defined _fys_Bans_Include_
    #endinput
#endif

#define _fys_Bans_Include_

// 纪录管理员操作
native void Admin_LogAction(int admin, const char[] action, const char[] message, any ...);

public SharedPlugin __pl_fys_Bans =
{
    name = "fys-Bans",
    file = "fys.bans.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_fys_Bans_SetNTVOptional()
{
    MarkNativeAsOptional("Admin_LogAction");
}
#endif