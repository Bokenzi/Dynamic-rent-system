/*
	Filterscript - Dynamic Port System
	Author: Bokenzi
	Created: 18/11/2020
*/

	#define FILTERSCRIPT

////
//
///

	#include < a_samp >
	#include < a_mysql >
	#include < sscanf2 >
	#include < Pawn.CMD >

////
//
///

	#define sql_host "localhost"
	#define sql_user "root"
	#define sql_password ""
	#define sql_database "worldwide_community"

////
//
///

	#define max_ports       30
	#define max_port_name   20

////
//
///

	#define d_port 			2552

////
//
///

	new MySQL:sql;

	enum admin_port_data {

		port_id, 
		port_name[max_port_name],
		Float: pos_x,
		Float: pos_y,
		Float: pos_z,
		bool: port_created

	}

	new PD[max_ports][admin_port_data],
		PlayerList[MAX_PLAYERS][50];

////
//
///

	public OnGameModeInit() {

		sql = mysql_connect(sql_host, sql_user, sql_password, sql_database);

		if(mysql_errno(sql) != 0)
			return SendRconCMD:("exit"), print("Neuspjesno povezivanje sa databazom"), false;

		return true;
	}

	public OnGameModeExit() {

		mysql_close(sql);

		return true;
	}

	public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {

		if(dialogid == 2552) {
			if(!response) return true; 
			else return Ports_SetPos(playerid, PlayerList[playerid][listitem]);
		}

		return true;
	}

	public SQL_PortRemoved(playerid, pid) {

		new str[64];

		format(str, sizeof str, "Uspjesno uklonjen port ID: %d", pid);
		SendClientMessage(playerid, -1, str);

		return Ports_Reload();
	}

	public SQL_PortAdded(playerid, const pname[]) {
		
		new str[64];

		format(str, sizeof str, "Uspjesno je dodan port: %s", pname);
		SendClientMessage(playerid, -1, str);

		return Ports_Reload();
	}

	public SQL_LoadPortCoodinates() {

		if(cache_num_rows()) {

			for(new i; i < cache_num_rows(); i++){

				cache_get_value_name_int(i, "port_id", PD[i][port_id]);
				cache_get_value_name_float(i, "X", PD[i][pos_x]);
				cache_get_value_name_float(i, "Y", PD[i][pos_y]);
				cache_get_value_name_float(i, "Z", PD[i][pos_z]);
				cache_get_value_name(i, "port_name", PD[i][port_name], max_port_name);

				PD[i][port_created] = true; 

			}
			printf("Admin port system: %d teleports loaded (%dms)", cache_num_rows(), cache_get_query_exec_time(MILLISECONDS));
		}
		return 1; 
	}

////
//
///

	CMD:port(playerid, params[])
		return Ports_Display(playerid);

	CMD:createport(playerid, params[]) {

		new name[max_port_name];

		if(sscanf(params, "s["#max_port_name"]", name))
			return SendClientMessage(playerid , -1, "Koristi: /createport [Ime porta]");

		else
			return Ports_Add(playerid, name);

	}

	CMD:deleteport(playerid, params[]) {

		new portid = Ports_GetClosest(playerid);

		if(portid == 0)
			return SendClientMessage(playerid, -1, "Greska: Morate biti blizu porta da bi ste ga obrisali");

		else return Ports_Remove(playerid, portid);
	}

////
//
///

	Ports_SetPos(playerid, pid) {

		new Float:x = PD[pid][pos_x], Float:y = PD[pid][pos_y], Float:z = PD[pid][pos_z], str[64];

		if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER){
			SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
		}
		else {
			SetPlayerPos(playerid, x, y, z);
		}

		format(str, sizeof str, "Teleportovali ste se do lokacije: %s", PD[pid][port_name]);
		SendClientMessage(playerid, -1, str);

		return 1; 
	}

	Ports_Display(playerid) {

		new list[1024];

		for(new i; i < sizeof(PD); ++i) {
			format(list, sizeof(list), "%s%s\n", list, PD[i][port_name]);
			PlayerList[playerid][i] = i;
		}

		return ShowPlayerDialog(playerid, d_port, DIALOG_STYLE_LIST, "Teleport", list, "Teleport", "Cancel");
	}

	Ports_Load()
		return mysql_tquery(sql, "SELECT * FROM `port_coordinates` ORDER BY `port_id` ASC", "SQL_LoadPortCoodinates", "");

	Ports_Reload() {

		if(Ports_Unload())
			return Ports_Load();

		return true;
	}

	Ports_Unload() {

	    for(new i; i < max_ports; i++){
	        if(!PD[i][port_created]) continue;
	        else {
	            PD[i][port_id] = 0;
	            PD[i][port_name] = EOS;
	            PD[i][pos_x] = 0.0;
	            PD[i][pos_y] = 0.0;
	            PD[i][pos_z] = 0.0;
	            PD[i][port_created] = false;
	        }
	    }
	    
	    return true; 
	}

	Ports_Add(playerid, const pname[]) {

		new str[140], Float: x, Float: y, Float: z; 

		GetPlayerPos(playerid, x, y, z);

		mysql_format(sql, str, sizeof(str), "INSERT INTO `port_coordinates` (`X`,`Y`,`Z`,`port_name`) VALUES('%f','%f','%f','%e')", x, y, z, pname);

		return mysql_tquery(sql, str, "SQL_PortAdded", "ds", playerid, pname);
	}

	Ports_Remove(playerid, pid) {

		new str[60];
		mysql_format(sql, str, sizeof(str), "DELETE FROM `port_coordinates` WHERE `port_id` = '%d'", pid);

		return mysql_tquery(sql, str, "SQL_PortRemoved", "dd", playerid, pid);
	}

	Ports_GetClosest(playerid) {

		new teleport_id = 0; 

		for(new i; i < max_ports; i++){
			if(PD[i][port_created]  == false) continue;
			else if(IsPlayerInRangeOfPoint(playerid, 10.0, PD[i][pos_x], PD[i][pos_y], PD[i][pos_z])) {
				teleport_id = PD[i][port_id];
			}
		}

		return teleport_id;
	}

////
//
///

	forward SQL_PortRemoved(playerid, pid);
	forward SQL_PortAdded(playerid, const pname[]);
	forward SQL_LoadPortCoodinates();