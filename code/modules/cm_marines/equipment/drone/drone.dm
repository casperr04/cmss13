// IO Drone
// Very cool
/obj/structure/drone
	name = "\improper M-2137 Beetle Drone"
	desc = "A small, mobile drone intended for intelligence and recon work. Can store small light things, like documents."
	icon = 'icons/obj/structures/mortar.dmi'
	icon_state = "mortar_m402"
	anchored = FALSE
	density = TRUE
	layer = FACEHUGGER_LAYER
	flags_atom = RELAY_CLICK
	var/obj/structure/machinery/computer/cameras/drone/internal_camera
