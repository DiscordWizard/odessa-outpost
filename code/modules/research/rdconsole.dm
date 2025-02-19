/*
Research and Development (R&D) Console

This is the main work horse of the R&D system. It contains the menus/controls for the Destructive Analyzer, Protolathe, and Circuit
imprinter. It also contains the /datum/research holder with all the known/possible technology paths and device designs.

Basic use: When it first is created, it will attempt to link up to related devices within 3 squares. It'll only link up if they
aren't already linked to another console. Any consoles it cannot link up with (either because all of a certain type are already
linked or there aren't any in range), you'll just not have access to that menu. In the settings menu, there are menu options that
allow a player to attempt to re-sync with nearby consoles. You can also force it to disconnect from a specific console.

The imprinting and construction menus do NOT require toxins access to access but all the other menus do. However, if you leave it
on a menu, nothing is to stop the person from using the options on that menu (although they won't be able to change to a different
one). You can also lock the console on the settings menu if you're feeling paranoid and you don't want anyone messing with it who
doesn't have toxins access.

When a R&D console is destroyed or even partially disassembled, you lose all research data on it. However, there are two ways around
this dire fate:
- The easiest way is to go to the settings menu and select "Sync Database with Network." That causes it to upload (but not download)
it's data to every other device in the game. Each console has a "disconnect from network" option that'll will cause data base sync
operations to skip that console. This is useful if you want to make a "public" R&D console or, for example, give the engineers
a circuit imprinter with certain designs on it and don't want it accidentally updating. The downside of this method is that you have
to have physical access to the other console to send data back. Note: An R&D console is on CentCom so if a random griffan happens to
cause a ton of data to be lost, an admin can go send it back.
- The second method is with Technology Disks and Design Disks. Each of these disks can hold a single technology or design datum in
it's entirety. You can then take the disk to any R&D console and upload it's data to it. This method is a lot more secure (since it
won't update every console in existence) but it's more of a hassle to do. Also, the disks can be stolen.
*/

/obj/machinery/computer/rdconsole
	name = "R&D control console"
	icon_keyboard = "rd_key"
	icon_screen = "rdcomp"
	light_color = COLOR_LIGHTING_PURPLE_MACHINERY
	circuit = /obj/item/weapon/circuitboard/rdconsole
	var/datum/research/files								//Stores all the collected research data.
	var/obj/item/weapon/computer_hardware/hard_drive/portable/disk = null	//Stores the data disk.

	var/obj/machinery/r_n_d/destructive_analyzer/linked_destroy = null	//Linked Destructive Analyzer
	var/obj/machinery/r_n_d/protolathe/linked_lathe             = null	//Linked Protolathe
	var/obj/machinery/r_n_d/circuit_imprinter/linked_imprinter  = null	//Linked Circuit Imprinter

	var/screen = 1.0	//Which screen is currently showing.
	var/id     = 0			//ID of the computer (for server restrictions).
	var/sync   = 1		//If sync = 0, it doesn't show up on Server Control Console

	req_access = list(access_moebius)	//Data and setting manipulation requires scientist access.

	var/datum/browser/popup

/obj/machinery/computer/rdconsole/proc/CallMaterialName(var/ID)
	var/return_name = ID
	switch(return_name)
		if("metal")
			return_name = "Metal"
		if(MATERIAL_GLASS)
			return_name = MATERIAL_GLASS
		if(MATERIAL_GOLD)
			return_name = "Gold"
		if(MATERIAL_SILVER)
			return_name = "Silver"
		if("plasma")
			return_name = "Solid Plasma"
		if(MATERIAL_URANIUM)
			return_name = "Uranium"
		if(MATERIAL_DIAMOND)
			return_name = "Diamond"
	return return_name

/obj/machinery/computer/rdconsole/proc/CallReagentName(var/ID)
	var/return_name = ID
	var/datum/reagent/temp_reagent
	for(var/R in (subtypesof(/datum/reagent)))
		temp_reagent = null
		temp_reagent = new R()
		if(temp_reagent.id == ID)
			return_name = temp_reagent.name
			qdel(temp_reagent)
			temp_reagent = null
			break
	return return_name

/obj/machinery/computer/rdconsole/proc/SyncRDevices() //Makes sure it is properly sync'ed up with the devices attached to it (if any).
	for(var/obj/machinery/r_n_d/D in range(3, src))
		if(!isnull(D.linked_console) || D.panel_open)
			continue
		if(istype(D, /obj/machinery/r_n_d/destructive_analyzer))
			if(isnull(linked_destroy))
				linked_destroy = D
				D.linked_console = src
		else if(istype(D, /obj/machinery/r_n_d/protolathe))
			if(isnull(linked_lathe))
				linked_lathe = D
				D.linked_console = src
		else if(istype(D, /obj/machinery/r_n_d/circuit_imprinter))
			if(isnull(linked_imprinter))
				linked_imprinter = D
				D.linked_console = src
	return

/obj/machinery/computer/rdconsole/proc/griefProtection() //Have it automatically push research to the centcomm server so wild griffins can't fuck up R&D's work
	for(var/obj/machinery/r_n_d/server/centcom/C in SSmachines.machinery)
		for(var/datum/tech/T in files.known_tech)
			C.files.AddTech2Known(T)
		for(var/datum/design/D in files.known_designs)
			C.files.AddDesign2Known(D)
		C.files.RefreshResearch()

/obj/machinery/computer/rdconsole/Initialize()
	..()
	files = new /datum/research(src) //Setup the research data holder.
	SyncRDevices()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/computer/rdconsole/LateInitialize()
	if(!id)
		for(var/obj/machinery/r_n_d/server/centcom/S in SSmachines.machinery)
			S.Initialize()
			break

/obj/machinery/computer/rdconsole/attackby(var/obj/item/weapon/D as obj, var/mob/user as mob)
	//Loading a disk into it.
	if(istype(D, /obj/item/weapon/computer_hardware/hard_drive/portable))
		if(disk)
			to_chat(user, SPAN_NOTICE("A disk is already loaded into the machine."))
			return

		user.drop_item()
		D.loc = src
		disk = D
		to_chat(user, SPAN_NOTICE("You add \the [D] to the machine."))
	else
		//The construction/deconstruction of the console code.
		..()

	src.updateUsrDialog()
	return

/obj/machinery/computer/rdconsole/emag_act(var/remaining_charges, var/mob/user)
	if(!emagged)
		playsound(src.loc, 'sound/effects/sparks4.ogg', 75, 1)
		emagged = 1
		user << SPAN_NOTICE("You disable the security protocols.")
		return 1

/obj/machinery/computer/rdconsole/Topic(href, href_list)
	if(..())
		return 1

	add_fingerprint(usr)

	if(href_list["close"])
		popup.close(usr)
		return

	usr.set_machine(src)


	// Disk operations
	if(disk)
		screen = 1.2
		if(href_list["eject_disk"]) //Eject the data disk.
			disk.forceMove(get_turf(src))
			disk = null
			screen = 1.0

		else if(href_list["disk_upload"]) //Updates the research holder with design data from the design disk.
			var/list/disk_designs = disk.find_files_by_type(/datum/computer_file/binary/design)

			for(var/f in disk_designs)
				var/datum/computer_file/binary/design/design_file = f

				if(design_file.copy_protected)
					continue
				if(!(design_file.design in files.possible_designs))
					continue

				files.AddDesign2Known(design_file.design)


			var/list/disk_technologies = disk.find_files_by_type(/datum/computer_file/binary/tech)

			for(var/f in disk_technologies)
				var/datum/computer_file/binary/tech/technology_file = f
				files.AddTech2Known(technology_file.tech)

			updateUsrDialog()
			griefProtection() //Update centcomm too

		else if(href_list["copy_tech"]) //Copys some technology data from the research holder to the disk.
			var/datum/tech/tech
			for(var/datum/tech/T in files.known_tech)
				if(href_list["copy_tech"] == T.id)
					tech = T
					break

			if(tech)
				var/datum/computer_file/binary/tech/tech_file = new
				tech_file.set_tech(tech.Copy())
				disk.store_file(tech_file)


		else if(href_list["copy_design"]) //Copy design data from the research holder to the design disk.
			var/datum/design/design = files.possible_design_ids[href_list["copy_design"]]

			if(design)
				disk.store_file(design.file.clone())


	if(href_list["menu"]) //Switches menu screens. Converts a sent text string into a number. Saves a LOT of code.
		var/temp_screen = text2num(href_list["menu"])
		if(temp_screen <= 1.1 || (3 <= temp_screen && 4.9 >= temp_screen) || allowed(usr) || emagged) //Unless you are making something, you need access.
			screen = temp_screen
		else
			to_chat(usr, "Unauthorized Access.")

	else if(href_list["eject_item"]) //Eject the item inside the destructive analyzer.
		if(linked_destroy)
			if(linked_destroy.busy)
				usr << SPAN_NOTICE("The destructive analyzer is busy at the moment.")

			else if(linked_destroy.loaded_item)
				linked_destroy.loaded_item.forceMove(get_turf(linked_destroy))
				linked_destroy.loaded_item = null
				linked_destroy.icon_state = "d_analyzer"
				screen = 2.1

	else if(href_list["deconstruct"]) //Deconstruct the item in the destructive analyzer and update the research holder.
		if(linked_destroy)
			if(linked_destroy.busy)
				usr << SPAN_NOTICE("The destructive analyzer is busy at the moment.")
			else
				if(!linked_destroy)
					return
				linked_destroy.busy = 1
				screen = 0.1
				updateUsrDialog()
				flick("d_analyzer_process", linked_destroy)
				spawn(24)
					if(linked_destroy)
						linked_destroy.busy = 0
						if(!linked_destroy.loaded_item)
							usr <<SPAN_NOTICE("The destructive analyzer appears to be empty.")
							screen = 1.0
							return

						for(var/T in linked_destroy.loaded_item.origin_tech)
							files.UpdateTech(T, linked_destroy.loaded_item.origin_tech[T])
						if(linked_lathe && linked_destroy.loaded_item.matter) // Also sends salvaged materials to a linked protolathe, if any.
							for(var/t in linked_destroy.loaded_item.matter)
								if(t in linked_lathe.materials)
									linked_lathe.materials[t] += linked_destroy.loaded_item.matter[t] * linked_destroy.decon_mod
									linked_lathe.materials[t] = min(linked_lathe.materials[t], linked_lathe.max_material_storage)


						linked_destroy.loaded_item = null
						for(var/obj/I in linked_destroy.contents)
							for(var/mob/M in I.contents)
								M.death()
							if(istype(I, /mob))
								var/mob/M = I
								M.death()
								qdel(I)
								linked_destroy.icon_state = "d_analyzer"
							if(I && istype(I,/obj/item/stack/material))//Only deconsturcts one sheet at a time instead of the entire stack
								var/obj/item/stack/material/S = I
								if(S.get_amount() > 1)
									S.use(1)
									linked_destroy.loaded_item = S
								else
									qdel(S)
									linked_destroy.icon_state = "d_analyzer"
							else
								if(!(I in linked_destroy.component_parts))
									qdel(I)
									linked_destroy.icon_state = "d_analyzer"

						use_power(linked_destroy.active_power_usage)
						screen = 2.1
						updateUsrDialog()

	else if(href_list["lock"]) //Lock the console from use by anyone without tox access.
		if(allowed(usr))
			screen = text2num(href_list["lock"])
		else
			usr << "Unauthorized Access."

	else if(href_list["sync"]) //Sync the research holder with all the R&D consoles in the game that aren't sync protected.
		screen = 0.0
		if(!sync)
			usr << SPAN_NOTICE("You must connect to the network first.")
		else
			griefProtection() //Putting this here because I dont trust the sync process
			spawn(30)
				if(src)
					for(var/obj/machinery/r_n_d/server/S in SSmachines.machinery)
						var/server_processed = 0
						if((id in S.id_with_upload) || istype(S, /obj/machinery/r_n_d/server/centcom))
							for(var/datum/tech/T in files.known_tech)
								S.files.AddTech2Known(T)
							for(var/datum/design/D in files.known_designs)
								S.files.AddDesign2Known(D)
							S.files.RefreshResearch()
							server_processed = 1
						if((id in S.id_with_download) && !istype(S, /obj/machinery/r_n_d/server/centcom))
							for(var/datum/tech/T in S.files.known_tech)
								files.AddTech2Known(T)
							for(var/datum/design/D in S.files.known_designs)
								files.AddDesign2Known(D)
							files.RefreshResearch()
							server_processed = 1
						if(!istype(S, /obj/machinery/r_n_d/server/centcom) && server_processed)
							S.produce_heat()
					screen = 1.6
					updateUsrDialog()

	else if(href_list["togglesync"]) //Prevents the console from being synced by other consoles. Can still send data.
		sync = !sync

	else if(href_list["build"]) //Causes the Protolathe to build something.
		if(linked_lathe)
			var/datum/design/being_built = files.possible_design_ids[href_list["build"]]

			if(being_built in files.known_designs)
				linked_lathe.addToQueue(being_built)

		screen = 3.1
		updateUsrDialog()

	else if(href_list["imprint"]) //Causes the Circuit Imprinter to build something.
		if(linked_imprinter)
			var/datum/design/being_built = files.possible_design_ids[href_list["imprint"]]

			if(being_built in files.known_designs)
				linked_imprinter.addToQueue(being_built)

		screen = 4.1
		updateUsrDialog()

	else if(href_list["disposeI"] && linked_imprinter)  //Causes the circuit imprinter to dispose of a single reagent (all of it)
		linked_imprinter.reagents.del_reagent(href_list["dispose"])

	else if(href_list["disposeallI"] && linked_imprinter) //Causes the circuit imprinter to dispose of all it's reagents.
		linked_imprinter.reagents.clear_reagents()

	else if(href_list["removeI"] && linked_lathe)
		linked_imprinter.removeFromQueue(text2num(href_list["removeI"]))

	else if(href_list["disposeP"] && linked_lathe)  //Causes the protolathe to dispose of a single reagent (all of it)
		linked_lathe.reagents.del_reagent(href_list["dispose"])

	else if(href_list["disposeallP"] && linked_lathe) //Causes the protolathe to dispose of all it's reagents.
		linked_lathe.reagents.clear_reagents()

	else if(href_list["removeP"] && linked_lathe)
		linked_lathe.removeFromQueue(text2num(href_list["removeP"]))

	else if(href_list["lathe_ejectsheet"] && linked_lathe) //Causes the protolathe to eject a sheet of material
		linked_lathe.eject(href_list["lathe_ejectsheet"], text2num(href_list["amount"]))

	else if(href_list["imprinter_ejectsheet"] && linked_imprinter) //Causes the protolathe to eject a sheet of material
		linked_imprinter.eject(href_list["imprinter_ejectsheet"], text2num(href_list["amount"]))

	else if(href_list["find_device"]) //The R&D console looks for devices nearby to link up with.
		screen = 0.0
		spawn(10)
			SyncRDevices()
			screen = 1.7
			updateUsrDialog()

	else if(href_list["disconnect"]) //The R&D console disconnects with a specific device.
		switch(href_list["disconnect"])
			if("destroy")
				linked_destroy.linked_console = null
				linked_destroy = null
			if("lathe")
				linked_lathe.linked_console = null
				linked_lathe = null
			if("imprinter")
				linked_imprinter.linked_console = null
				linked_imprinter = null

	else if(href_list["reset"]) //Reset the R&D console's database.
		griefProtection()
		var/choice = alert("Database Reset", "Are you sure you want to reset the R&D console database? Data lost cannot be recovered.", "Continue", "Cancel")
		if(choice == "Continue")
			screen = 0.0
			qdel(files)
			files = new /datum/research(src)
			spawn(20)
				screen = 1.6
				updateUsrDialog()

	else if (href_list["print"]) //Print research information
		screen = 0.5
		spawn(20)
			var/obj/item/weapon/paper/PR = new/obj/item/weapon/paper
			PR.name = "list of researched technologies"
			PR.info = "<center><b>[station_name()] Science Laboratories</b>"
			PR.info += "<h2>[ (text2num(href_list["print"]) == 2) ? "Detailed" : ] Research Progress Report</h2>"
			PR.info += "<i>report prepared at [stationtime2text()] station time</i></center><br>"
			if(text2num(href_list["print"]) == 2)
				PR.info += GetResearchListInfo()
			else
				PR.info += GetResearchLevelsInfo()
			PR.info_links = PR.info
			PR.icon_state = "paper_words"
			PR.loc = src.loc
			spawn(10)
				screen = ((text2num(href_list["print"]) == 2) ? 5.0 : 1.1)
				updateUsrDialog()

	updateUsrDialog()
	return

/obj/machinery/computer/rdconsole/proc/GetResearchLevelsInfo()
	var/dat
	dat += "<UL>"
	for(var/datum/tech/T in files.known_tech)
		if(T.level < 1)
			continue
		dat += "<LI>"
		dat += "[T.name]"
		dat += "<UL>"
		dat +=  "<LI>Level: [T.level]"
		dat +=  "<LI>Summary: [T.desc]"
		dat += "</UL><br>"
	return dat

/obj/machinery/computer/rdconsole/proc/GetResearchListInfo()
	var/dat
	dat += "<UL>"
	for(var/datum/design/D in files.known_designs)
		dat += "<LI><B>[D.name]</B>: [D.desc]"
	dat += "</UL>"
	return dat

/obj/machinery/computer/rdconsole/attack_hand(mob/user as mob)
	if(stat & (BROKEN|NOPOWER))
		return

	user.set_machine(src)
	interact(user)

/obj/machinery/computer/rdconsole/interact(mob/user as mob)
	var/dat = ""
	files.RefreshResearch()
	switch(screen) //A quick check to make sure you get the right screen when a device is disconnected.
		if(2 to 2.9)
			if(isnull(linked_destroy))
				screen = 2.0
			else if(isnull(linked_destroy.loaded_item))
				screen = 2.1
			else
				screen = 2.2
		if(3 to 3.9)
			if(isnull(linked_lathe))
				screen = 3.0
		if(4 to 4.9)
			if(isnull(linked_imprinter))
				screen = 4.0

	switch(screen)

		//////////////////////R&D CONSOLE SCREENS//////////////////
		if(0.0)
			dat += "Updating Database..."

		if(0.1)
			dat += "Processing and Updating Database..."

		if(0.2)
			dat += "SYSTEM LOCKED<BR><BR>"
			dat += "<A href='?src=\ref[src];lock=1.6'>Unlock</A>"

		if(0.3)
			dat += "Constructing Prototype. Please Wait..."

		if(0.4)
			dat += "Imprinting Circuit. Please Wait..."

		if(0.5)
			dat += "Printing Research Information. Please Wait..."

		if(1.0) //Main Menu
			dat += "Main Menu:<BR><BR>"
			dat += "Loaded disk: "
			if(disk)
				var/disk_name = disk.get_disk_name()

				if(!disk_name)
					disk_name = "data disk"

				dat += disk_name
			else
				dat += "none"

			dat += "<HR><UL>"
			dat += "<LI><A href='?src=\ref[src];menu=1.1'>Current Research Levels</A>"
			dat += "<LI><A href='?src=\ref[src];menu=5.0'>View Researched Technologies</A>"
			if(disk)
				dat += "<LI><A href='?src=\ref[src];menu=1.2'>Disk Operations</A>"
			else
				dat += "<LI>Disk Operations"
			if(linked_destroy)
				dat += "<LI><A href='?src=\ref[src];menu=2.2'>Destructive Analyzer Menu</A>"
			if(linked_lathe)
				dat += "<LI><A href='?src=\ref[src];menu=3.1'>Protolathe Construction Menu</A>"
			if(linked_imprinter)
				dat += "<LI><A href='?src=\ref[src];menu=4.1'>Circuit Construction Menu</A>"
			dat += "<LI><A href='?src=\ref[src];menu=1.6'>Settings</A>"
			dat += "</UL>"

		if(1.1) //Research viewer
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];print=1'>Print This Page</A><HR>"
			dat += "Current Research Levels:<BR><BR>"
			dat += GetResearchLevelsInfo()
			dat += "</UL>"

		if(1.2) // Disk menu
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"

			if(disk)
				var/list/disk_designs = disk.find_files_by_type(/datum/computer_file/binary/design)
				var/list/disk_technologies = disk.find_files_by_type(/datum/computer_file/binary/tech)

				// Filter disk designs
				for(var/f in disk_designs)
					var/datum/computer_file/binary/design/design_file = f
					if(design_file.copy_protected)
						disk_designs -= design_file
					if(!(design_file.design in files.possible_designs))
						disk_designs -= design_file

				if(!length(disk_designs))
					dat += "The disk has no accessible design files stored on it."
				else
					dat += "Design files:<BR>"
					for(var/f in disk_designs)
						var/datum/computer_file/binary/design/design_file = f
						dat += "[design_file.design.name]<BR>"

				if(!length(disk_technologies))
					dat += "The disk has no accessible technology files stored on it."
				else
					dat += "<BR>Technology files:<BR>"
					for(var/f in disk_technologies)
						var/datum/computer_file/binary/tech/tech_file = f
						dat += "[tech_file.tech.name] (level [tech_file.tech.level])<BR>"

				dat += "<HR>Operations: "

				if(length(disk_designs) || length(disk_technologies))
					dat += "<A href='?src=\ref[src];disk_upload=1'>Upload to Database</A> || "

				if(disk.can_store_file(size = 4))
					dat += "<A href='?src=\ref[src];menu=1.3'>Load Design to Disk</A> || "

				if(disk.can_store_file(size = 8))
					dat += "<A href='?src=\ref[src];menu=1.4'>Load Technology to Disk</A> || "

				dat += "<A href='?src=\ref[src];eject_disk=1'>Eject Disk</A>"

		if(1.3) // Disk design copy submenu
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=1.2'>Return to Disk Operations</A><HR>"
			dat += "Load Design to Disk:<BR><BR>"
			dat += "<UL>"
			for(var/datum/design/D in files.known_designs)
				dat += "<LI>[D.name] "
				dat += "<A href='?src=\ref[src];copy_design=[D.id]'>\[copy to disk\]</A>"
			dat += "</UL>"

		if(1.4) // Disk technology copy submenu
			dat += "<BR><A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=1.2'>Return to Disk Operations</A><HR>"
			dat += "Load Technology to Disk:<BR><BR>"
			dat += "<UL>"
			for(var/datum/tech/T in files.known_tech)
				dat += "<LI>[T.name] "
				dat += "\[<A href='?src=\ref[src];copy_tech=[T.id]'>copy to disk</A>\]"
			dat += "</UL>"

		if(1.6) //R&D console settings
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"
			dat += "R&D Console Setting:<HR>"
			dat += "<UL>"
			if(sync)
				dat += "<LI><A href='?src=\ref[src];sync=1'>Sync Database with Network</A><BR>"
				dat += "<LI><A href='?src=\ref[src];togglesync=1'>Disconnect from Research Network</A><BR>"
			else
				dat += "<LI><A href='?src=\ref[src];togglesync=1'>Connect to Research Network</A><BR>"
			dat += "<LI><A href='?src=\ref[src];menu=1.7'>Device Linkage Menu</A><BR>"
			dat += "<LI><A href='?src=\ref[src];lock=0.2'>Lock Console</A><BR>"
			dat += "<LI><A href='?src=\ref[src];reset=1'>Reset R&D Database</A><BR>"
			dat += "<UL>"

		if(1.7) //R&D device linkage
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=1.6'>Settings Menu</A><HR>"
			dat += "R&D Console Device Linkage Menu:<BR><BR>"
			dat += "<A href='?src=\ref[src];find_device=1'>Re-sync with Nearby Devices</A><HR>"
			dat += "Linked Devices:"
			dat += "<UL>"
			if(linked_destroy)
				dat += "<LI>Destructive Analyzer <A href='?src=\ref[src];disconnect=destroy'>(Disconnect)</A>"
			else
				dat += "<LI>(No Destructive Analyzer Linked)"
			if(linked_lathe)
				dat += "<LI>Protolathe <A href='?src=\ref[src];disconnect=lathe'>(Disconnect)</A>"
			else
				dat += "<LI>(No Protolathe Linked)"
			if(linked_imprinter)
				dat += "<LI>Circuit Imprinter <A href='?src=\ref[src];disconnect=imprinter'>(Disconnect)</A>"
			else
				dat += "<LI>(No Circuit Imprinter Linked)"
			dat += "</UL>"

		////////////////////DESTRUCTIVE ANALYZER SCREENS////////////////////////////
		if(2.0)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"
			dat += "NO DESTRUCTIVE ANALYZER LINKED TO CONSOLE<BR><BR>"

		if(2.1)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"
			dat += "No Item Loaded. Standing-by...<BR><HR>"

		if(2.2)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"
			dat += "Deconstruction Menu<HR>"
			dat += "Name: [linked_destroy.loaded_item.name]<BR>"
			dat += "Origin Tech:"
			dat += "<UL>"
			for(var/T in linked_destroy.loaded_item.origin_tech)
				dat += "<LI>[CallTechName(T)] [linked_destroy.loaded_item.origin_tech[T]]"
				for(var/datum/tech/F in files.known_tech)
					if(F.name == CallTechName(T))
						dat += " (Current: [F.level])"
						break
			dat += "</UL>"
			dat += "<HR><A href='?src=\ref[src];deconstruct=1'>Deconstruct Item</A> || "
			dat += "<A href='?src=\ref[src];eject_item=1'>Eject Item</A> || "

		/////////////////////PROTOLATHE SCREENS/////////////////////////
		if(3.0)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"
			dat += "NO PROTOLATHE LINKED TO CONSOLE<BR><BR>"

		if(3.1)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=3.4'>View Queue</A> || "
			dat += "<A href='?src=\ref[src];menu=3.2'>Material Storage</A> || "
			dat += "<A href='?src=\ref[src];menu=3.3'>Chemical Storage</A><HR>"
			dat += "Protolathe Menu:<BR><BR>"
			dat += "<B>Material Amount:</B> [linked_lathe.TotalMaterials()] cm<sup>3</sup> (MAX: [linked_lathe.max_material_storage])<BR>"
			dat += "<B>Chemical Volume:</B> [linked_lathe.reagents.total_volume] (MAX: [linked_lathe.reagents.maximum_volume])<HR>"
			dat += "<UL>"
			for(var/datum/design/D in files.known_designs)
				if(!(D.build_type & PROTOLATHE))
					continue
				var/temp_dat
				dat += "<div class='block' style ='padding: 0px; overflow: auto; margin-left:-2px'>"
				for(var/M in D.materials)
					temp_dat += ", [D.materials[M]] [CallMaterialName(M)]"
				for(var/T in D.chemicals)
					temp_dat += ", [D.chemicals[T]] [CallReagentName(T)]"
				if(temp_dat)
					temp_dat = " \[[copytext(temp_dat, 3)]\]"
				var/iconName = getAtomCacheFilename(D.build_path)
				dat += "<div style ='float: left; margin-left:0px; height:24px;width:24px;' class='statusDisplayItem'><img src= [iconName] height=24 width=24></div>"
				if(linked_lathe.canBuild(D))
					dat += "<LI><B><A href='?src=\ref[src];build=[D.id]'>[D.name]</A></B><div style = 'float: right;'>[temp_dat]</div>"
				else
					dat += "<LI><B>[D.name]</B><div style = 'float: right;'>[temp_dat]</div>"
				dat += "</div>"


			dat += "</UL>"

		if(3.2) //Protolathe Material Storage Sub-menu
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=3.1'>Protolathe Menu</A><HR>"
			dat += "Material Storage<BR><HR>"
			dat += "<UL>"
			for(var/M in linked_lathe.materials)
				var/amount = linked_lathe.materials[M]
				dat += "<LI><B>[capitalize(M)]</B>: [amount] sheets"
				if(amount > 0)
					dat += " || Eject "
					for (var/C in list(1, 3, 5, 10, 15, 20, 25, 30, 40))
						if(amount < C)
							break
						dat += "[C > 1 ? ", " : ""]<A href='?src=\ref[src];lathe_ejectsheet=[M];amount=[C]'>[C]</A> "

					dat += " or <A href='?src=\ref[src];lathe_ejectsheet=[M];amount=50'>max</A> sheets"
				dat += ""
			dat += "</UL>"

		if(3.3) //Protolathe Chemical Storage Submenu
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=3.1'>Protolathe Menu</A><HR>"
			dat += "Chemical Storage<BR><HR>"
			for(var/datum/reagent/R in linked_lathe.reagents.reagent_list)
				dat += "Name: [R.name] | Units: [R.volume] "
				dat += "<A href='?src=\ref[src];disposeP=[R.id]'>(Purge)</A><BR>"
				dat += "<A href='?src=\ref[src];disposeallP=1'><U>Disposal All Chemicals in Storage</U></A><BR>"

		if(3.4) // Protolathe queue
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=3.1'>Protolathe Menu</A><HR>"
			dat += "Queue<BR><HR>"
			if(!linked_lathe.queue.len)
				dat += "Empty"
			else
				var/tmp = 1
				for(var/datum/design/D in linked_lathe.queue)
					if(tmp == 1)
						if(linked_lathe.busy)
							dat += "<B>1: [D.name]</B><BR>"
						else
							dat += "<B>1: [D.name]</B> (Awaiting materials) <A href='?src=\ref[src];removeP=[tmp]'>(Remove)</A><BR>"
					else
						dat += "[tmp]: [D.name] <A href='?src=\ref[src];removeP=[tmp]'>(Remove)</A><BR>"
					++tmp

		///////////////////CIRCUIT IMPRINTER SCREENS////////////////////
		if(4.0)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A><HR>"
			dat += "NO CIRCUIT IMPRINTER LINKED TO CONSOLE<BR><BR>"

		if(4.1)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=4.4'>View Queue</A> || "
			dat += "<A href='?src=\ref[src];menu=4.3'>Material Storage</A> || "
			dat += "<A href='?src=\ref[src];menu=4.2'>Chemical Storage</A><HR>"
			dat += "Circuit Imprinter Menu:<BR><BR>"
			dat += "Material Amount: [linked_imprinter.TotalMaterials()] cm<sup>3</sup><BR>"
			dat += "Chemical Volume: [linked_imprinter.reagents.total_volume]<HR>"
			dat += "<UL>"
			for(var/datum/design/D in files.known_designs)
				if(!(D.build_type & IMPRINTER))
					continue
				dat += "<div class='block' style ='padding: 0px; overflow: auto; margin-left:-2px'>"
				var/temp_dat
				for(var/M in D.materials)
					temp_dat += ", [D.materials[M]] [CallMaterialName(M)]"
				for(var/T in D.chemicals)
					temp_dat += ", [D.chemicals[T]] [CallReagentName(T)]"
				if(temp_dat)
					temp_dat = " \[[copytext(temp_dat,3)]\]"
				var/iconName = getAtomCacheFilename(D.build_path)
				dat += "<div style ='float: left; margin-left:0px; height:24px;width:24px;' class='statusDisplayItem'><img src= [iconName] height=24 width=24></div>"

				if(linked_imprinter.canBuild(D))
					dat += "<LI><B><A href='?src=\ref[src];imprint=[D.id]'>[D.name]</A></B><div style = 'float: right;'>[temp_dat]</div>"
				else
					dat += "<LI><B>[D.name]</B><div style = 'float: right;'>[temp_dat]</div>"
				dat += "</div>"
			dat += "</UL>"

		if(4.2)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=4.1'>Imprinter Menu</A><HR>"
			dat += "Chemical Storage<BR><HR>"
			if(linked_imprinter.reagents.reagent_list.len)
				for(var/datum/reagent/R in linked_imprinter.reagents.reagent_list)
					dat += "Name: [R.name] | Units: [R.volume] "
					dat += "<A href='?src=\ref[src];disposeI=[R.id]'>(Purge)</A><BR>"
				dat += "<A href='?src=\ref[src];disposeallI=1'><U>Disposal All Chemicals in Storage</U></A><BR>"

		if(4.3)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=4.1'>Circuit Imprinter Menu</A><HR>"
			dat += "Material Storage<BR><HR>"
			dat += "<UL>"
			for(var/M in linked_imprinter.materials)
				var/amount = linked_imprinter.materials[M]
				dat += "<LI><B>[capitalize(M)]</B>: [amount] sheets</sup>"
				if(amount > 0)
					dat += " || Eject: "
					for (var/C in list(1, 3, 5, 10, 15, 20, 25, 30, 40))
						if(amount < C)
							break
						dat += "[C > 1 ? ", " : ""]<A href='?src=\ref[src];imprinter_ejectsheet=[M];amount=[C]'>[C]</A> "

					dat += " or <A href='?src=\ref[src];imprinter_ejectsheet=[M];amount=50'>max</A> sheets"
				dat += ""
			dat += "</UL>"

		if(4.4)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];menu=4.1'>Circuit Imprinter Menu</A><HR>"
			dat += "Queue<BR><HR>"
			if(linked_imprinter.queue.len == 0)
				dat += "Empty"
			else
				var/tmp = 1
				for(var/datum/design/D in linked_imprinter.queue)
					if(tmp == 1)
						dat += "<B>1: [D.name]</B><BR>"
					else
						dat += "[tmp]: [D.name] <A href='?src=\ref[src];removeI=[tmp]'>(Remove)</A><BR>"
					++tmp

		///////////////////Research Information Browser////////////////////
		if(5.0)
			dat += "<A href='?src=\ref[src];menu=1.0'>Main Menu</A> || "
			dat += "<A href='?src=\ref[src];print=2'>Print This Page</A><HR>"
			dat += "List of Researched Technologies and Designs:"
			dat += GetResearchListInfo()

	popup = new(user, "rdconsole","Research and Development Console", 850, 600, src)
	popup.set_content("<TITLE>Research and Development Console</TITLE><HR>[jointext(dat, null)]")
	popup.open()

/obj/machinery/computer/rdconsole/robotics
	name = "robotics R&D console"
	id = 2
	req_access = list(access_robotics)

/obj/machinery/computer/rdconsole/core
	name = "core R&D console"
	id = 1
