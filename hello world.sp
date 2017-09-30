#pragma semicolon 1

#define DEBUG

#define 			PLUGIN_AUTHOR		"iakhremchik"
#define 			PLUGIN_VERSION		"start"

/*CONFIG*/

#define			START_TIME				15
#define 			ZOMBIE_HEALTH 		500
#define 			MAP_LIGHTS 			"b"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <cstrike>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "zombierun",
	author = PLUGIN_AUTHOR,
	description = "zombie mod",
	version = PLUGIN_VERSION,
	url = "iakhremchik.ru"
};

Handle hTimer;

bool g_isZombie[MAXPLAYERS + 1], g_isGame;

int iTimer;

UserMsg g_FadeUserMsgId;

public void OnPluginStart() 
{ 
	
	HookEvent("round_start", zr_Round_Start, EventHookMode_PostNoCopy);
	HookEvent("round_end", zr_Round_End, EventHookMode_Pre);   
	HookEvent("player_death", zr_PlayerDeath);
	RegConsoleCmd("zversion", zr_showInfo);
	RegConsoleCmd("infect", zr_infect);
	g_FadeUserMsgId = GetUserMessageId( "Fade" );
}

/*MAP START*/

public void OnMapStart()
{
	SetLightStyle(0, MAP_LIGHTS);
}

/*PUT IN SERVER*/

public void OnClientPutInServer(int client) 
{ 
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage_Pre); 
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamage_Post);
} 

/*DISCONNECT*/

public void OnClientDisconnect(int client) 
{ 
	if ( IsClientInGame(client) ) 
	{
		SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch); 
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage_Pre);
		SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamage_Post);
	}
} 

/*SHOW INFO*/

public Action zr_showInfo(int client, int args) 
{ 
	PrintToConsole(client, "МОДИФИКАЦИЯ--------zombieRun\nВЕРСИЯ-------------%s", PLUGIN_VERSION);
	CS_TerminateRound(5.0, CSRoundEnd_TerroristWin, true);
	return Plugin_Handled; 
}


/* ROUND START */

public Action zr_Round_Start(Handle event, char[] name, bool dontBroadcast)  
{ 
	PrintToChatAll("\x04-------------НАЧАЛО РАУНДА----------------");
	g_isGame = true;
	iTimer = START_TIME;
	hTimer = CreateTimer(1.0, zr_RoundTimer, _, TIMER_REPEAT);
} 

/*ROUND TIMER*/

public Action zr_RoundTimer(Handle timer)
{
	char ok[] = "";
	
	if(iTimer >= 2 && iTimer <= 4)
		ok = "Ы";
	else if(iTimer == 1)
		ok = "У";
		
	for (int i = 1; i <=MaxClients ; i++)
	{
		if (IsClientInGame(i))
		{
			if( iTimer > 0 )
				PrintHintText(i, "РАУНД НАЧНЕТСЯ ЧЕРЕЗ %d СЕКУНД%s", iTimer, ok);
			else
			{
				int client = get_random_player();
				infect(client);
				
				for (int c = 1; c < MaxClients; c ++)
				{
					if( IsClientInGame(c) && IsPlayerAlive(c) && !g_isZombie[c])
					{
						CS_SwitchTeam(c, CS_TEAM_CT);
					}
				}				
				char name[32];
				GetClientName(client, name, 32);
				PrintHintText(i, "ИГРОК %s ЗАРАЖЕН!!", name);
			}
		}
	}
	
	if( iTimer == 0)
		return Plugin_Stop;
		
	iTimer--;
	
	return Plugin_Continue;
}

/*ROUND END*/

public Action zr_Round_End(Handle event, char[] name, bool dontBroadcast)  
{ 
	PrintToChatAll("\x03-------------КОНЕЦ РАУНДА----------------");
	g_isGame = false;
	if( iTimer > 0 )
		KillTimer(hTimer);
	for (int i = 1; i <=MaxClients ; i++)
	{
		if (IsClientConnected(i)) 
		{
			g_isZombie[i] = false;
		}
	}
} 

/*INFECT-ADMIN*/

public Action zr_infect(int client, int args)
{
	infect(client);
	return Plugin_Handled;
}

/*DEATH*/

public void zr_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//int victim = event.GetInt("userid");
	//int attacker = event.GetInt("attacker");
	
}

/*PICK UP WEAPON*/

public Action OnWeaponEquip(int client, int _weapon) 
{ 
	if( g_isZombie[client] )
		return Plugin_Handled;
	return Plugin_Changed;
	
}

/*SWITCH WEAPON*/

public Action OnWeaponSwitch(int client) 
{
	if( g_isZombie[client] )
		return Plugin_Handled;
	return Plugin_Changed;
}

/*TAKE DAMAGE*/

//post
public Action OnTakeDamage_Post(int victim) 
{
	if( !g_isZombie[victim] )
		fadescreen(victim, 50, 50, false);
}

//pre
public Action OnTakeDamage_Pre(int victim)
{
	if( !g_isGame )
		return Plugin_Handled;
	return Plugin_Continue;
}

/*FADE SCREEN*/

public void fadescreen(int client, int duration, int holdtime, bool always)
{
	if( !IsPlayerAlive(client) )
		return;
	int clients[2];
	clients[0] = client;
	
	int color[4] = { 255, 0, 0, 30 };
	Handle message = StartMessageEx(g_FadeUserMsgId, clients, 1);
	
	BfWrite bf = UserMessageToBfWrite(message);
	bf.WriteShort(duration);
	bf.WriteShort(holdtime);
	bf.WriteShort(always?(0x0002 | 0x0008):(0x0001 | 0x0010));
	bf.WriteByte(color[0]);
	bf.WriteByte(color[1]);
	bf.WriteByte(color[2]);
	bf.WriteByte(color[3]);
	EndMessage();
}

/*INFECT*/

public void infect(int client)
{
	if( g_isGame )
	{
		Client_RemoveAllWeapons(client, "", true);
		Client_GiveWeapon(client, "weapon_knife", true);
		g_isZombie[client] = true;
		SetEntityHealth(client, ZOMBIE_HEALTH);
		fadescreen(client, 10, 10, true);
		CS_SwitchTeam(client, CS_TEAM_T);
	}
}

/* GET RANDOM PLAYER*/

stock int get_random_player() 
{
	int[] clients = new int[MaxClients];
	int clientCount;

	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		if (IsPlayerAlive(i))
		{
			clients[clientCount++] = i;
		}
	}

	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
