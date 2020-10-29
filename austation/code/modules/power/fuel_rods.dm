/obj/item/twohanded/required/fuel_rod
	var/rad_strength = 500
	var/half_life = 2000 // how many depletion ticks are needed to half the fuel_power (1 tick = 1 second)
	var/time_created = 0
	var/og_fuel_power = 0.20 //the original fuel power value
	var/process = FALSE
	// The depletion where depletion_final() will be called (and does something)
	var/depletion_threshold = 100
	// How fast this rod will deplete
	var/depletion_speed_modifier = 1
	var/depleted_final = FALSE // depletion_final should run only once

/obj/item/twohanded/required/fuel_rod/Initialize()
	. = ..()
	time_created = world.time
	AddComponent(/datum/component/radioactive, rad_strength, src) // This should be temporary for it won't make rads go lower than 350
	if(process)
		START_PROCESSING(SSobj, src)

/obj/item/twohanded/required/fuel_rod/Destroy()
	if(process)
		STOP_PROCESSING(SSobj, src)
	. = ..()

// Child types should override this or your fuel rod will be turned to plutonium fuel rod
/obj/item/twohanded/required/fuel_rod/proc/depletion_final()
	var/obj/machinery/atmospherics/components/trinary/nuclear_reactor/N = loc
	if(istype(N))
		var/obj/item/twohanded/required/fuel_rod/plutonium/P = new(loc)
		P.depletion = depletion
		N.fuel_rods += P
		qdel(src)

/obj/item/twohanded/required/fuel_rod/deplete(amount=0.035) // override for the one in rmbk.dm
	depletion += amount * depletion_speed_modifier
	if(depletion >= depletion_threshold && !depleted_final)
		depleted_final = TRUE
		depletion_final()

/obj/item/twohanded/required/fuel_rod/plutonium
	fuel_power = 0.20
	name = "Plutonium-239 Fuel Rod"
	desc = "A highly energetic titanium sheathed rod containing a sizeable measure of weapons grade plutonium, it's highly efficient as nuclear fuel, but will cause the reaction to get out of control if not properly utilised."
	icon_state = "inferior"
	rad_strength = 1500
	process = TRUE // for half life code
	depletion_threshold = 300

/obj/item/twohanded/required/fuel_rod/plutonium/process()
	fuel_power = og_fuel_power * 0.5**((world.time - time_created) / half_life SECONDS) // halves the fuel power every half life (33 minutes)

/obj/item/twohanded/required/fuel_rod/plutonium/depletion_final()
	if(fuel_power < 10)
		var/obj/machinery/atmospherics/components/trinary/nuclear_reactor/N = loc
		fuel_power = 0
		playsound(loc, 'sound/effects/supermatter.ogg', 100, TRUE)
		if(istype(N))
			var/obj/item/twohanded/required/fuel_rod/depleted/D = new(loc)
			D.depletion = depletion
			N.fuel_rods += D
			qdel(src)

/obj/item/twohanded/required/fuel_rod/depleted
	name = "Depleted Fuel Rod"
	desc = "A highly radioactive fuel rod which has expended most of it's useful energy."
	icon_state = "normal"
	rad_strength = 6000 // smelly

// Does nothing. Depletion_threshold doesn't matter anyway.
/obj/item/twohanded/required/fuel_rod/depleted/depletion_final()
	return

// Master type for material optional (or requiring, wyci) and/or producing rods
/obj/item/twohanded/required/fuel_rod/material
	// Whether the rod has been harvested. Should be set in expend().
	var/expended = FALSE
	// The material that will be inserted and then multiplied (or not). Should be some sort of /obj/item/stack
	var/material_type
	// The name of material that'll be used for texts
	var/material_name
	var/initial_amount = 0
	// The maximum amount of material the rod can hold
	var/max_initial_amount = 10
	var/grown_amount = 0
	// The multiplier for growth. 1 for the same 2 for double etc etc
	var/multiplier = 2
	// After this depletion, you won't be able to add new materials
	var/material_input_deadline = 25

// Called when the rod is fully harvested
/obj/item/twohanded/required/fuel_rod/material/proc/expend()
	expended = TRUE

// Basic checks for material rods
/obj/item/twohanded/required/fuel_rod/material/proc/check_material_input(mob/user)
	if(depletion >= material_input_deadline)
		to_chat(user, "<span class='warning'>The sample slots have sealed themselves shut, it's too late to add [material_name] now!</span>") // no cheesing in crystals at 100%
		return FALSE
	if(expended)
		to_chat(user, "<span class='warning'>\The [src]'s material slots have already been used.</span>")
		return FALSE
	return TRUE

// The actual growth
/obj/item/twohanded/required/fuel_rod/material/depletion_final()
	grown_amount = initial_amount * multiplier

/obj/item/twohanded/required/fuel_rod/material/attackby(obj/item/W, mob/user, params)
	var/obj/item/stack/M = W
	if(istype(M, material_type))
		if(!check_material_input(user))
			return
		if(initial_amount < max_initial_amount)
			var/adding = min((max_initial_amount - initial_amount), M.amount)
			M.amount -= adding
			initial_amount += adding
			to_chat(user, "<span class='notice'>You insert [adding] \the [M] into \the [src].</span>")
			M.zero_amount()
		else
			to_chat(user, "<span class='warning'>\The [src]'s material slots are full!</span>")
			return
	else
		return ..()

/obj/item/twohanded/required/fuel_rod/material/attack_self(mob/user)
	if(expended)
		to_chat(user, "<span class='notice'>You have already removed [material_name] from \the [src].</span>")
		return

	if(depleted_final)
		new material_type(user.loc, grown_amount)
		to_chat(user, "<span class='notice'>You harvest [grown_amount] [material_name] from \the [src].</span>")
		grown_amount = 0
		expend()
	else if(depletion)
		to_chat(user, "<span class='warning'>\The [src] has not fissiled enough to fully grow the sample. The progress bar shows it is [min(depletion/depletion_threshold*100,100)]% complete.</span>")
	else if(initial_amount)
		new material_type(user.loc, initial_amount)
		to_chat(user, "<span class='notice'>You remove [initial_amount] [material_name] from \the [src].</span>")
		initial_amount = 0

/obj/item/twohanded/required/fuel_rod/material/examine(mob/user)
	. = ..()
	if(expended)
		. += "<span class='warning'>The material slots have been slagged by the extreme heat, you can't grow [material_name] in this rod again...</span>"
		return
	else if(depleted_final)
		. += "<span class='warning'>This fuel rod's [material_name] are now fully grown, and it currently bears [grown_amount] [material_name].</span>"
		return
	if(depletion)
		. += "<span class='danger'>The sample is [min(depletion/depletion_threshold*100,100)]% fissiled.</span>"
	. += "<span class='disarm'>[initial_amount]/[max_initial_amount] of the slots for [material_name] are full.</span>"

/obj/item/twohanded/required/fuel_rod/material/telecrystal
	name = "Telecrystal Fuel Rod"
	desc = "A disguised titanium sheathed rod containing several small slots infused with uranium dioxide. Permits the insertion of telecrystals to grow more. Fissiles much faster than its standard counterpart"
	icon_state = "telecrystal"
	fuel_power = 0.30 // twice as powerful as a normal rod, you're going to need some engineering autism if you plan to mass produce TC
	depletion_speed_modifier = 3 // headstart, otherwise it takes two hours
	rad_strength = 1500
	max_initial_amount = 8
	multiplier = 3
	material_type = /obj/item/stack/telecrystal
	material_name = "telecrystals"

/obj/item/twohanded/required/fuel_rod/material/telecrystal/depletion_final()
	..()
	fuel_power = 0.60 // thrice as powerful as plutonium, you'll want to get this one out quick!
	name = "Exhausted Telecrystal Fuel Rod"
	desc = "A highly energetic, disguised titanium sheathed rod containing a number of slots filled with greatly expanded telecrystals which can be removed by hand. It's extremely efficient as nuclear fuel, but will cause the reaction to get out of control if not properly utilised."
	icon_state = "telecrystal_used"
	AddComponent(/datum/component/radioactive, 3000, src)

/obj/item/twohanded/required/fuel_rod/material/bananium
	name = "Bananium Fuel Rod"
	desc = "A hilarious heavy-duty fuel rod which fissiles a bit slower than its cowardly counterparts. However, its cutting-edge cosmic clown technology allows rooms for extraordinarily exhilarating extraterrestrial element called bananium to menacingly multiply."
	icon_state = "bananium"
	fuel_power = 0.15
	depletion_speed_modifier = 3
	rad_strength = 350
	max_initial_amount = 10
	multiplier = 3
	material_type = /obj/item/stack/sheet/mineral/bananium
	material_name = "sheets of bananium"

/obj/item/twohanded/required/fuel_rod/material/bananium/deplete(amount=0.035)
	..()
	if(initial_amount == max_initial_amount && prob(10))
		playsound(src, pick('sound/items/bikehorn.ogg', 'sound/misc/bikehorn_creepy.ogg'), 50) // HONK

/obj/item/twohanded/required/fuel_rod/material/bananium/depletion_final()
	..()
	fuel_power = 0.3 // Be warned
	name = "Fully Grown Bluespace Crystal Fuel Rod"
	desc = "A hilarious heavy-duty fuel rod which fissiles a bit slower than it cowardly counterparts. Its greatly grimacing grwoth stage is now over, and bananium outgrowth hums as if it's blatantly honking bike horns."
	icon_state = "bananium_used"
	AddComponent(/datum/component/radioactive, 1250, src)
