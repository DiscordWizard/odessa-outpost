
//Chemical Reagents - Initialises all /datum/reagent into a list indexed by reagent id
/proc/initialize_chemical_reagents()
	var/paths = typesof(/datum/reagent) - /datum/reagent
	chemical_reagents_list = list()
	for(var/path in paths)
		var/datum/reagent/D = new path()
		if(!D.name)
			continue
		chemical_reagents_list[D.id] = D


/datum/reagent
	var/name = "Reagent"
	var/id = "reagent"
	var/description = "A non-descript chemical."
	var/taste_description = "old rotten bandaids"
	var/taste_mult = 1 //how this taste compares to others. Higher values means it is more noticable
	var/datum/reagents/holder = null
	var/reagent_state = SOLID
	var/list/data = null
	var/volume = 0
	var/metabolism = REM // This would be 0.2 normally
	var/ingest_met = 0
	var/touch_met = 0
	var/dose = 0
	var/max_dose = 0
	var/overdose = 0
	var/addiction_threshold = 0
	var/addiction_chance = 0
	var/withdrawal_threshold = 0
	var/withdrawal_rate = REM * 2
	var/scannable = 0 // Shows up on health analyzers.
	var/affects_dead = 0
	var/glass_icon_state = null
	var/glass_name = null
	var/glass_desc = null
	var/glass_center_of_mass = null
	var/color = "#000000"
	var/color_weight = 1

	var/chilling_point
	var/chilling_message = "crackles and freezes!"
	var/chilling_sound = 'sound/effects/bubbles.ogg'
	var/list/chilling_products

	var/heating_point
	var/heating_message = "begins to boil!"
	var/heating_sound = 'sound/effects/bubbles.ogg'
	var/list/heating_products

/datum/reagent/proc/remove_self(amount) // Shortcut
	if(holder) //Apparently it's possible to have holderless reagents.
		holder.remove_reagent(id, amount)


// This doesn't apply to skin contact - this is for, e.g. extinguishers and sprays.
// The difference is that reagent is not directly on the mob's skin - it might just be on their clothing.
/datum/reagent/proc/touch_mob(mob/M, amount)
	return

/datum/reagent/proc/touch_obj(obj/O, amount) // Acid melting, cleaner cleaning, etc
	return

/datum/reagent/proc/touch_turf(turf/T, amount) // Cleaner cleaning, lube lubbing, etc, all go here
	return

// Called when this reagent is first added to a mob
/datum/reagent/proc/on_mob_add(mob/living/L)
	return

// Called when this reagent is removed while inside a mob
/datum/reagent/proc/on_mob_delete(mob/living/L)
	return

// Currently, on_mob_life is only called on carbons. Any interaction with non-carbon mobs (lube) will need to be done in touch_mob.
/datum/reagent/proc/on_mob_life(mob/living/carbon/M, var/alien, var/location)
	if(!istype(M))
		return
	if(!affects_dead && M.stat == DEAD)
		return

	if(overdose && (dose > overdose) && (location != CHEM_TOUCH))
		overdose(M, alien)
	var/removed = metabolism
	if(ingest_met && (location == CHEM_INGEST))
		removed = ingest_met
	if(touch_met && (location == CHEM_TOUCH))
		removed = touch_met
	removed = min(removed, volume)
	max_dose = max(volume, max_dose)
	dose = min(dose + removed, max_dose)
	if(removed >= (metabolism * 0.1) || removed >= 0.1) // If there's too little chemical, don't affect the mob, just remove it
		switch(location)
			if(CHEM_BLOOD)
				affect_blood(M, alien, removed)
			if(CHEM_INGEST)
				affect_ingest(M, alien, removed)
			if(CHEM_TOUCH)
				affect_touch(M, alien, removed)
	remove_self(removed)
	return

/datum/reagent/proc/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	return

/datum/reagent/proc/affect_ingest(var/mob/living/carbon/M, var/alien, var/removed)
	affect_blood(M, alien, removed * 0.5)
	return

/datum/reagent/proc/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	return

/datum/reagent/proc/overdose(var/mob/living/carbon/M, var/alien) // Overdose effect. Doesn't happen instantly.
	M.adjustToxLoss(REM)
	return

/datum/reagent/proc/initialize_data(var/newdata) // Called when the reagent is created.
	if(!isnull(newdata))
		data = newdata
	return

/datum/reagent/proc/mix_data(var/newdata, var/newamount) // You have a reagent with data, and new reagent with its own data get added, how do you deal with that?
	return

/datum/reagent/proc/get_data() // Just in case you have a reagent that handles data differently.
	if(data && istype(data, /list))
		return data.Copy()
	else if(data)
		return data
	return null

// Addiction
/datum/reagent/proc/addiction_act_stage1(mob/living/carbon/M)
	if(prob(30))
		to_chat(M, SPAN_NOTICE("You feel like having some [name] right about now."))

/datum/reagent/proc/addiction_act_stage2(mob/living/carbon/M)
	if(prob(30))
		to_chat(M, SPAN_NOTICE("You feel like you need [name]. You just can't get enough."))

/datum/reagent/proc/addiction_act_stage3(mob/living/carbon/M)
	if(prob(30))
		to_chat(M, SPAN_DANGER("You have an intense craving for [name]."))

/datum/reagent/proc/addiction_act_stage4(mob/living/carbon/M)
	if(prob(30))
		to_chat(M, SPAN_DANGER("You're not feeling good at all! You really need some [name]."))

/datum/reagent/proc/addiction_end(mob/living/carbon/M)
	to_chat(M, SPAN_NOTICE("You feel like you've gotten over your need for [name]."))

// Withdrawal
/datum/reagent/proc/withdrawal_start(mob/living/carbon/M)
	return

/datum/reagent/proc/withdrawal_act(mob/living/carbon/M)
	return

/datum/reagent/proc/withdrawal_end(mob/living/carbon/M)
	return


/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	. = ..()
	holder = null

/* DEPRECATED - TODO: REMOVE EVERYWHERE */

/datum/reagent/proc/reaction_turf(turf/target)
	touch_turf(target)

/datum/reagent/proc/reaction_obj(obj/target)
	touch_obj(target)

/datum/reagent/proc/reaction_mob(mob/target)
	touch_mob(target)

/datum/reagent/proc/custom_temperature_effects(temperature)
	return

