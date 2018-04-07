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

import globals : g_focused;
import derelict.imgui.imgui;

pragma(inline) nothrow @nogc
bool isPointInside(ImVec4* clip_rect, ref ImVec2 pos) {
	return (pos.x >= clip_rect.x && pos.x <= clip_rect.z &&
			pos.y >= clip_rect.y && pos.y <= clip_rect.w);
}

import godot.globalconstants;
class ImguiContext : GodotScript!Spatial {
	
	immutable int[] Keys = [
		keyTab, 		// ImGuiKey_Tab
		keyLeft, 		// ImGuiKey_LeftArrow
		keyRight, 		// ImGuiKey_RightArrow
		keyUp, 			// ImGuiKey_UpArrow
		keyDown, 		// ImGuiKey_DownArrow
		keyPageup,		// ImGuiKey_Pageup
		keyPagedown,	// ImGuiKey_Pagedown
		keyHome, 		// ImGuiKey_Home
		keyEnd, 		// ImGuiKey_End
		keyDelete, 		// ImGuiKey_Delete
		keyBackspace, 	// ImGuiKey_Backspace
		keyEnter,		// ImGuiKey_Enter
		keyEscape,		// ImGuiKey_Escape
		keyA,			// ImGuiKey_A
		keyC,			// ImGuiKey_C
		keyV,			// ImGuiKey_V
		keyX,			// ImGuiKey_X
		keyY,			// ImGuiKey_Y
		keyZ			// ImGuiKey_Z
	];

	// if these don't match, we done fucked uplong
	static assert(Keys.length == ImGuiKey_COUNT);

	// godot related resources
	Ref!ImageTexture font_texture;
	@OnReady!"ig" ImmediateGeometry ig;

	// WHEELU
	float scroll_wheel = 0.0f;
	ubyte[16] pressed_keys;
	ubyte pressed_index;

	// DEBUG CLIPPING
	float clip_factor = 1.0f;
	float clip_offset = 0.0f;

	@Method
	void _ready() {

		import godot.visualserver;
		VisualServerSingleton vs = VisualServer;

		// make ImmediateGeometry AABB absurdly large, so that it is not culled when we look away from where the IG node is located in space
		AABB aabb = AABB(Vector3(0, 0, 0), Vector3(1, 1, 1));
		auto grown_aabb = aabb.grow(1000000);
		vs.instanceSetCustomAabb(ig._getVisualInstanceRid(), grown_aabb);

		// init us
		initialize();
		print("IMGUI READY");

	}

	@Method
	void _process(float delta) {
		newFrame(delta);

		auto vp_size = owner.getViewport().size;
		float width = vp_size.x;
		float height = vp_size.y;
		// igSliderFloat("clip_factor", &clip_factor, 0.0f, 20.0f);
		// igSliderFloat("clip_offset", &clip_offset, -height, height);

	}

	@Method
	void _input(InputEvent ev) {

		if (g_focused) return;

		if (InputEventKey key = cast(InputEventKey) ev) {
			if (key.pressed) {
				if (key.scancode >= 32 && key.scancode <= 255) {
					pressed_keys[pressed_index] = cast(ubyte)key.scancode;
					pressed_index += 1;
				}
			}
		}

		if (InputEventMouseButton btn = cast(InputEventMouseButton) ev) {
			if (btn.buttonIndex == buttonWheelUp && btn.pressed) {
				scroll_wheel += 1;
			} else if (btn.buttonIndex == buttonWheelDown && btn.pressed) {
				scroll_wheel -= 1;
			}
		}

	}

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

		io.MouseDoubleClickTime = 1;

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

		ubyte* pixels;
		int width, height;
		int bytes_per_pixel;
		ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &width, &height, &bytes_per_pixel);
		ImFontAtlas_SetTexID(io.Fonts, cast(void*)1);

		int bytes_to_copy = width * height * bytes_per_pixel;
		PoolByteArray bytes = PoolByteArray();
		bytes.resize(bytes_to_copy);
		foreach (i; 0..bytes_to_copy) {
			bytes[i] = pixels[i];
		}

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

		import godot.shadermaterial;
		Ref!ShaderMaterial sm = cast(Ref!ShaderMaterial)ig.getMaterialOverride();
		sm.setShaderParam("viewport_size", vp_size);
		sm.setShaderParam("clip_factor", clip_factor);
		sm.setShaderParam("clip_offset", clip_offset);

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
				
				bool skip = false;
				ImDrawCmd* pcmd = ImDrawList_GetCmdPtr(cmd_list, i);

				if (pcmd.UserCallback) {
					pcmd.UserCallback(cmd_list, pcmd);
				} else {

					// bind texture, scissor, draw command here
					if (pcmd.TextureId != null) {
						sm.setShaderParam("font_texture", Variant(font_texture));
					} else {
						sm.setShaderParam("font_texture", Variant(null));
					}

					ig.begin(Mesh.PrimitiveType.primitiveTriangles);
					foreach (e_i; 0_..pcmd.ElemCount) {
						auto vtx = vertices[indices[idx_buffer_offset + e_i]];
						ig.addVertex(Vector3(vtx.pos.x * (2.0 / vp_size.x) - 1, vtx.pos.y  * (-2.0 / vp_size.y) + 1, 0.0));
						ig.setUv(Vector2(vtx.uv.x, vtx.uv.y));
						// store scissor rect x, y (top left) in Normal and z, w (bottom right) in Uv2
						ig.setNormal(Vector3(pcmd.ClipRect.x, pcmd.ClipRect.y, 0.0f));
						ig.setUv2(Vector2(pcmd.ClipRect.z, pcmd.ClipRect.w));
						
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
	import core.stdc.string : strcmp;

	void newFrame(float dt) {

		ImGuiIO* io = igGetIO();

		if (igGetFrameCount() > 0) endFrame();

		auto vp_size = owner.getViewport().size;
		io.DisplaySize = ImVec2(vp_size.x, vp_size.y);
		io.DisplayFramebufferScale = ImVec2(1.0f, 1.0f);
		io.DeltaTime = dt;
		
		if (!g_focused) {

			Vector2 mouse_pos = owner.getViewport().getMousePosition();
			io.MousePos = ImVec2(mouse_pos.x, mouse_pos.y);

			io.MouseDown[0] = Input.isMouseButtonPressed(buttonLeft);
			io.MouseDown[2] = Input.isMouseButtonPressed(buttonMiddle);
			io.MouseDown[1] = Input.isMouseButtonPressed(buttonRight);

			if (igIsAnyItemActive() && !igIsMouseDown(0)) {

				foreach (sc; pressed_keys[0..pressed_index]) {
					if (sc >= 65 && sc <= 90) {
						if (!Input.isKeyPressed(keyShift)) {
							sc += 32;
						}
					}
					ImGuiIO_AddInputCharacter(cast(ubyte)sc);
				}

				pressed_keys[0..16] = 0;
				pressed_index = 0;
				
				foreach (i, k; Keys) {
					io.KeysDown[i] = Input.isKeyPressed(k);
				}

			} else {
				foreach (i, k; Keys) {
					io.KeysDown[i] = Input.isKeyPressed(k);
				}
			}

			io.KeyCtrl = Input.isKeyPressed(keyControl);
			io.KeyShift = Input.isKeyPressed(keyShift);
			io.KeyAlt = Input.isKeyPressed(keyAlt);

			io.MouseWheel += scroll_wheel;
			scroll_wheel = 0;

		}

		// finally call back into imgui
		igNewFrame();

	}

	void endFrame() {
		
		igRender();

	}

}