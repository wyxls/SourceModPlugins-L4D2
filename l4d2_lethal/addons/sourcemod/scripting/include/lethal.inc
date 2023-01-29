#if defined _lethal_helpers_included_
  #endinput
#endif
#define _lethal_helpers_included_

/**
 * Allows only specified client to use the lethal (even if he is not an admin).
 *
 * @param client		Client index given. Set 0 to allow for everybody. -1 to forbid for all.
 *
 * @error				Wrong number of arguments.
 * @noreturn
 */
native void Lethal_SetAllowedClient(int client);

/**
 * Allows all clients to use the lethal (defined by ConVars settings).
 *
 * @noparams
 * @noerrors
 * @noreturn
 */
native void Lethal_SetAllowedClientsAll();

/**
 * Allows or forbid indirrect damage ally by the lethal (this not include direct bullet damage, controlled by "l4d2_lw_ff" ConVar).
 *
 * @param bool			true by default, false - remove damage.
 *
 * @error				Wrong number of arguments.
 * @noreturn
 */
native void Lethal_FriendlyFire(bool bDamageAlly);

public void __pl_lethal_helpers_SetNTVOptional()
{
	MarkNativeAsOptional("lethal_SetAllowedClient");
	MarkNativeAsOptional("lethal_SetAllowedClientsAll");
	MarkNativeAsOptional("lethal_FriendlyFire");
}

public SharedPlugin __pl_lethal_helpers =
{
	name = "lethal_helpers",
	file = "Lethal_AR.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

