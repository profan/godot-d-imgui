module dimgui;

import std.traits : isDelegate, ReturnType, ParameterTypeTuple;
auto bindDelegate(T, string file = __FILE__, size_t line = __LINE__)(T t) if(isDelegate!T) {

	static T dg;
	dg = t;

	extern(C) static ReturnType!T func(ParameterTypeTuple!T args) {
		return dg(args);
	}

	return &func;

} // bindDelegate (thanks Destructionator)

void loadImgui() {
	import derelict.util.loader;
	import derelict.imgui.imgui : DerelictImgui;

	import godot : print;
	DerelictImgui.load();
	print("Loaded DerelictImgui.");

}

import godot : GodotScript;
import godot.node : Node;
import godot.node2d : Node2D;
import godot.spatial : Spatial;
import godot.input : Input;
import godot.inputevent : InputEvent;
import godot.inputeventkey : InputEventKey;
import godot.inputeventmouse : InputEventMouse;
import godot.inputeventmousebutton : InputEventMouseButton;
import godot.surfacetool;
import godot.arraymesh;
import godot.viewport;
import godot.image;
import godot.imagetexture;
import godot.immediategeometry;
import godot.texture;
import godot.mesh;
import godot;

class ImguiContext : GodotScript!Spatial {
    import derelict.imgui.imgui;
	import godot.globalconstants;
	
	immutable int[] Keys = [
		keyTab, 		// ImGuiKey_Tab
		keyLeft, 		// ImGuiKey_LeftArrow
		keyRight, 		// ImGuiKey_RightArrow
		keyPageup,		// ImGuiKey_Pageup
		keyPagedown,	// ImGuiKey_Pagedown
		keyUp, 			// ImGuiKey_UpArrow
		keyDown, 		// ImGuiKey_DownArrow
		keyHome, 		// ImGuiKey_Home
		keyEnd, 		// ImGuiKey_End
		keyBackspace, 	// ImGuiKey_Backspace
		keyDelete, 		// ImGuiKey_Delete
		keyEscape,		// ImGuiKey_Escape
		keyEnter,		// ImGuiKey_Enter
		keyA,			// ImGuiKey_A
		keyC,			// ImGuiKey_C
		keyV,			// ImGuiKey_V
		keyX,			// ImGuiKey_X
		keyY,			// ImGuiKey_Y
		keyZ			// ImGuiKey_Z
	];

	// if these don't match, we done fucked up
	static assert(Keys.length == ImGuiKey_COUNT);

	bool[3] mouse_buttons_pressed;
	float scroll_wheel = 0.0f;

	// godot related resources
	Ref!ArrayMesh imgui_mesh;
	PoolVector3Array vertex_array;
	PoolIntArray index_array;
	PoolColorArray color_array;
	PoolVector3Array uv_array;
	Ref!ImageTexture font_texture;

	RID font_tex_id;

	@OnReady!"ig" ImmediateGeometry ig;

	@Method
	void _ready() {

		import godot.visualserver;
		VisualServerSingleton vs = VisualServer;
		Image img = vs.textureGetData(vs.getWhiteTexture());

		// make ImmediateGeometry AABB absurdly large, so that it is not culled when we look away from where the IG node is located in space
		AABB aabb = AABB(Vector3(0, 0, 0), Vector3(1, 1, 1));
		auto grown_aabb = aabb.grow(1000000);
		vs.instanceSetCustomAabb(ig._getVisualInstanceRid(), grown_aabb);

		// font_texture = memnew!ImageTexture();
		// font_texture.createFromImage(img);
		
		imgui_mesh = memnew!ArrayMesh();
		print("IMGUI READY");

		// init us
		initialize();

	}

	@Method
	void _process(float delta) {
		newFrame(delta);
	}

	/*
	static immutable (char)* inputs;

	@Method
	void _input(InputEvent ev) {
		if (InputEventKey key = cast(InputEventKey)ev) {
			if (igIsAnyItemActive() && key.pressed) {
				auto sc = key.scancode;
				if (sc == keyLeft ||
					sc == keyRight ||
					sc == keyPageup ||
					sc == keyPagedown ||
					sc == keyUp ||
					sc == keyDown ||
					sc == keyHome ||
					sc == keyEnd ||
					sc == keyBackspace ||
					sc == keyDelete ||
					sc == keyEscape ||
					sc == keyEnter) return;
				inputs = key.unicode;
			}
		}
	}
	*/

	// internal functions
	void initialize() {

		import godot.inputeventkey;
		import godot.globalconstants;

		ImGuiIO* io = igGetIO();

		io.KeyMap[ImGuiKey_Tab] = ImGuiKey_Tab;
		io.KeyMap[ImGuiKey_LeftArrow] = ImGuiKey_LeftArrow;
		io.KeyMap[ImGuiKey_RightArrow] = ImGuiKey_RightArrow;
		io.KeyMap[ImGuiKey_UpArrow] = ImGuiKey_UpArrow;
		io.KeyMap[ImGuiKey_DownArrow] = ImGuiKey_DownArrow;
		io.KeyMap[ImGuiKey_Home] = ImGuiKey_Home;
		io.KeyMap[ImGuiKey_End] = ImGuiKey_End;
		io.KeyMap[ImGuiKey_Backspace] = ImGuiKey_Backspace;
		io.KeyMap[ImGuiKey_Delete] = ImGuiKey_Delete;
		io.KeyMap[ImGuiKey_Escape] = ImGuiKey_Escape;
		io.KeyMap[ImGuiKey_Enter] = ImGuiKey_Enter;
		io.KeyMap[ImGuiKey_A] = ImGuiKey_A;
		io.KeyMap[ImGuiKey_C] = ImGuiKey_C;
		io.KeyMap[ImGuiKey_V] = ImGuiKey_V;
		io.KeyMap[ImGuiKey_X] = ImGuiKey_X;
		io.KeyMap[ImGuiKey_Y] = ImGuiKey_Y;
		io.KeyMap[ImGuiKey_Z] = ImGuiKey_Z;

		io.RenderDrawListsFn = bindDelegate(&renderDrawLists);
		io.SetClipboardTextFn = bindDelegate(&setClipboardText);
		io.GetClipboardTextFn = bindDelegate(&getClipboardText);

		createDeviceObjects();

	}

	void createDeviceObjects() {

		/*generate teh fonts*/
		createFontTexture();

	}

	void createFontTexture() {

		ImGuiIO* io = igGetIO();

		import godot.visualserver : VisualServer, VisualServerSingleton;

		VisualServerSingleton vs = VisualServer;

		RID tex_id = vs.textureCreate();
		font_tex_id = tex_id;

		ubyte* pixels;
		int width, height;
		int bytes_per_pixel;
		ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &width, &height, &bytes_per_pixel);
		ImFontAtlas_SetTexID(io.Fonts, cast(void*)1);

		int bytes_to_copy = width * height * bytes_per_pixel;
		PoolByteArray bytes = PoolByteArray();
		print("copying: ", bytes_to_copy, " bytes into PoolByteArray.");
		foreach (i; 0..bytes_to_copy) {
			bytes.append(pixels[i]);
		}
		print("bytes size: ", bytes.length);

		Ref!Image tex_img = memnew!Image();
		tex_img.createFromData(width, height, false, Image.Format.formatRgba8, bytes);
		font_texture = memnew!ImageTexture;
		font_texture.createFromImage(tex_img);

	}

	nothrow
	void renderDrawLists(ImDrawData* data) {

		auto vp_size = owner.getViewport().size;
		float width = vp_size.x;
		float height = vp_size.y;

		ig.clear();
		foreach (n; 0..data.CmdListsCount) {

			ImDrawList* cmd_list = data.CmdLists[n];
			ImDrawIdx idx_buffer_offset;

			auto vertices_count = ImDrawList_GetVertexBufferSize(cmd_list);
			auto indices_count = ImDrawList_GetIndexBufferSize(cmd_list);

			ImDrawVert[] vertices = ImDrawList_GetVertexPtr(cmd_list, 0)[0..vertices_count];
			ImDrawIdx[] indices = ImDrawList_GetIndexPtr(cmd_list, 0)[0..indices_count];

			auto cmd_count = ImDrawList_GetCmdSize(cmd_list);

			foreach (i; 0..cmd_count) {
				
				ImDrawCmd* pcmd = ImDrawList_GetCmdPtr(cmd_list, i);

				if (pcmd.UserCallback) {
					pcmd.UserCallback(cmd_list, pcmd);
				} else {

					// bind texture, scissor, draw command here
					if (pcmd.TextureId != null) {
						import godot.shadermaterial;
						Ref!ShaderMaterial sm = cast(Ref!ShaderMaterial)ig.getMaterialOverride();
						sm.setShaderParam("font_texture", Variant(font_texture));
					} else {
						import godot.shadermaterial;
						Ref!ShaderMaterial sm = cast(Ref!ShaderMaterial)ig.getMaterialOverride();
						sm.setShaderParam("font_texture", Variant(null));
					}

					ig.begin(Mesh.PrimitiveType.primitiveTriangles);
					foreach (e_i; 0_..pcmd.ElemCount) {
						auto vtx = vertices[indices[idx_buffer_offset + e_i]];
						ig.addVertex(Vector3(vtx.pos.x * (2.0 / vp_size.x) - 1, vtx.pos.y  * (-2.0 / vp_size.y) + 1, 0.0));
						ig.setUv(Vector2(vtx.uv.x, vtx.uv.y));
						
						ubyte[4] c = (cast(ubyte*)(&vtx.col))[0..4];
						float[4] col = [c[0] / 255.0, c[1] / 255.0, c[2] / 255.0, c[3] / 255.0];
						Color godot_col = Color(col[0], col[1], col[2], col[3]);
						ig.setColor(godot_col);
						
					}
					ig.end();

				}

				idx_buffer_offset += pcmd.ElemCount;

			}

		}

	}

	nothrow
	void setClipboardText(void* user_data, const (char*) text) {
		import godot.os;
		OS.clipboard = String(text);
	}

	nothrow
	const (char*) getClipboardText(void* user_data) {
		import godot.os;
		return OS.clipboard.utf8().ptr;
	}

	void newFrame(float dt) {

		ImGuiIO* io = igGetIO();

		if (igGetFrameCount() > 0) endFrame();

		auto vp_size = owner.getViewport().size;
		io.DisplaySize = ImVec2(vp_size.x, vp_size.y);
		io.DisplayFramebufferScale = ImVec2(1.0f, 1.0f);
		io.DeltaTime = dt;
		
		Vector2 mouse_pos = owner.getViewport().getMousePosition();
		io.MousePos = ImVec2(mouse_pos.x, mouse_pos.y);

		io.MouseDown[0] = Input.isMouseButtonPressed(buttonLeft);
		io.MouseDown[1] = Input.isMouseButtonPressed(buttonMiddle);
		io.MouseDown[2] = Input.isMouseButtonPressed(buttonRight);

		foreach (i, k; Keys) {
			io.KeysDown[i] = Input.isKeyPressed(k);
		}

		io.KeyCtrl = Input.isKeyPressed(keyMaskCtrl);
		io.KeyShift = Input.isKeyPressed(keyMaskShift);
		io.KeyAlt = Input.isKeyPressed(keyMaskAlt);

		if (igIsAnyItemActive()) {
			ImGuiIO_AddInputCharacter(cast(ulong)65);
		}

		io.MouseWheel = scroll_wheel;

		// finally call back into imgui
		igNewFrame();

	}

	void endFrame() {
		
		igRender();

	}

}