import godot;

// all our shit
import player;

// deps
import dimgui : loadImgui, ImguiContext;

mixin GodotNativeLibrary!(
	"adder",
	Player,
	ImguiContext,
	(GodotInitOptions o) { 
		print("Library initialized");
		loadImgui();
	},
	(GodotTerminateOptions o) {
		print("Library terminated");
	}
);
