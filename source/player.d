import godot.object.all;

import godot.input;
import godot.collisionshape;
import godot.kinematicbody;
import godot.camera;

import godot;

enum PlayerActions : const (char)* {
    Forwards = "player_forwards",
    Backwards = "player_backwards",
    StrafeLeft = "player_strafe_left",
    StrafeRight = "player_strafe_right",
    PrimaryFire = "player_primary",
    SecondaryFire = "player_secondary",
    Jump = "player_jump",
    Crouch = "player_crouch",
    Noclip = "player_noclip",
    DebugDraw = "player_debugdraw",
    Sprint = "player_sprint"
}

Vector3 x(ref Basis b) {
    return b.getRow(1);
}

 Vector3 y(ref Basis b) {
    return b.getRow(2);
}

Vector3 z(ref Basis b) {
    return b.getRow(0);
}

@property
Vector3 up(Transform t) {
    return -t.basis.y;
}

@property
Vector3 fwd(Transform t) {
    return -t.basis.z;
}

@property
Vector3 left(Transform t) {
    return -t.basis.x;
}

@property
Vector3 right(Transform t) {
    return t.basis.x;
}

import globals : focused = g_focused, g_noclip;

class Player : GodotScript!KinematicBody {

    float GRAVITON = 9.8f / 16; // 9.8 WHAT
    float MAX_MOVEMENT_SPEED = 18.0f; // SOME SHIT PER SECOND
    float MOVEMENT_SPEED = 1.5f; // .. what per second?
    float JUMP_HEIGHT = 32.0f;
    float ACCELERATION = 10.0f;
    float FRICTION = 1.2705f;

    // noclip
    float NOCLIP_SPEED = 12.0f;

    alias owner this;

    Vector3 velocity;
    Vector3 direction;
    Vector2 last_mouse_pos;
    Vector2 last_mouse_delta;

    // original
    Transform original_transform;
    import std.math : PI_4;
    float yaw = 0.0f, pitch = 0.0f;

    @OnReady!"camera" Camera camera;
    @OnReady!"caster" RayCast caster;
    @OnReady!"collision" CollisionShape collision;
    bool moving_again = false;

    @Method
    void _ready() {
        collisionSafeMargin = 0.0015;
        original_transform = transform;
    }

    @Method
    void _input(InputEvent ev) {

        import derelict.imgui.imgui;

        if (InputEventMouseMotion mouse_ev = cast(InputEventMouseMotion)ev) {
            if (focused) {
                if (!moving_again) {
                    auto pos = mouse_ev.position;
                    last_mouse_delta = Vector2.init;
                    last_mouse_pos = pos;
                    moving_again = true;
                } else {
                    auto pos = mouse_ev.position;
                    last_mouse_delta = last_mouse_pos - pos;
                    last_mouse_pos = pos;
                }
            }
        }

        if (InputEventKey key = cast(InputEventKey) ev) {
            if (key.isAction("ui_cancel") && key.pressed) {
                focused = !focused;
                if (!focused) {
                    moving_again = false;
                    Input.setMouseMode(Input.MouseMode.mouseModeVisible);
                } else {
                    Input.setMouseMode(Input.MouseMode.mouseModeCaptured);
                    auto pos = owner.getViewport().getMousePosition();
                    last_mouse_delta = Vector2();
                    last_mouse_pos = pos;
                }
            } else if (key.isAction(PlayerActions.Noclip) && key.pressed) {
                g_noclip = !g_noclip;
                collision.disabled = g_noclip;
            } else if (key.isAction(PlayerActions.DebugDraw) && key.pressed) {
                auto vp = owner.getViewport();
                auto cur_mode = vp.debugDraw;
                cur_mode = cast(Viewport.DebugDraw)((cast(int)cur_mode + 1) % cast(int)Viewport.DebugDraw.max);
                vp.debugDraw = cur_mode;
            }
        }

    }

    static float rad2deg(float r) {
        import std.math : PI;
        return r * 180 / PI;
    }

    @Method
    void _process(float delta) {

        static bool showDemoWindow = true;

        import derelict.imgui.imgui;
        if (igGetFrameCount() > 0) {

            // igShowDemoWindow(&showDemoWindow)i;

            static long current_screen;
            static Vector2 last_window_size;
            static Vector2 last_window_pos;
            static float max_gravity = 8.0f;
            static bool process_status;

            static int total_frames_below_sixty;

            if (delta > (1000.0f/60.0f)) total_frames_below_sixty += 1;

            igBegin("Godot", &process_status, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_AlwaysAutoResize);
            igText("frametime: %2.2f ms (%.1f FPS)", 1000.0f / igGetIO().Framerate, igGetIO().Framerate);
            if (igTreeNode("frametime stats")) {
                igText("- frames below 60: %d", total_frames_below_sixty);
                igTreePop();
            }
            float dynamic_mem_mbytes = (OS.getDynamicMemoryUsage() / 1000.0) / 1000.0f;
            igText("dynamic memory usage: %2.2f MB", dynamic_mem_mbytes);
            float static_mem_mbytes = (OS.getStaticMemoryUsage() / 1000.0) / 1000.0f;
            igText("static memory usage: %2.2f MB", static_mem_mbytes);
            float static_mem_mbytes_peak = (OS.getStaticMemoryPeakUsage() / 1000.0) / 1000.0f;
            igText("static memory usage - peak: %2.2f MB ", static_mem_mbytes_peak);
            auto screen_size = OS.getScreenSize();
            igText("screen size: %d x %d", cast(int)screen_size.x, cast(int)screen_size.y);
            Viewport vp = owner.getViewport();
            auto vp_size = vp.size;
            igText("viewport size: %d x %d", cast(int)vp_size.x, cast(int)vp_size.y);
            igText("- objects: %d", vp.getRenderInfo(Viewport.RenderInfo.renderInfoObjectsInFrame));
            igText("- vertices: %d", vp.getRenderInfo(Viewport.RenderInfo.renderInfoVerticesInFrame));
            igText("- drawcalls: %d", vp.getRenderInfo(Viewport.RenderInfo.renderInfoDrawCallsInFrame));
            igText("- material changes: %d", vp.getRenderInfo(Viewport.RenderInfo.renderInfoMaterialChangesInFrame));
            igText("- surface changes: %d", vp.getRenderInfo(Viewport.RenderInfo.renderInfoSurfaceChangesInFrame));
            igText("- shader changes: %d", vp.getRenderInfo(Viewport.RenderInfo.renderInfoShaderChangesInFrame));
            if (OS.isWindowFullscreen()) {
                if (igButton("go windowed")) {
                    OS.setWindowFullscreen(false);
                    OS.setWindowSize(last_window_size);
                    OS.setWindowPosition(last_window_pos);
                }
            } else {
                if (igButton("go fullscreen")) {
                    last_window_size = OS.getWindowSize();
                    last_window_pos = OS.getWindowPosition();
                    current_screen = OS.getCurrentScreen();
                    last_window_pos.x = last_window_pos.x + (1920 * current_screen);
                    OS.setWindowFullscreen(true);
                }
            }
            igEnd();

            static bool opened = true;
            igBegin("Player", &opened, ImGuiWindowFlags_AlwaysAutoResize);
            igInputFloat3("player position", owner.transform.origin, -1, ImGuiInputTextFlags_ReadOnly);
            igInputFloat3("player velocity", velocity.coord);
            igInputFloat("max gravity", &max_gravity);
            igSliderFloat("gravity", &GRAVITON, 0.0f, max_gravity);
            igSliderFloat("max movement speed", &MAX_MOVEMENT_SPEED, 0.0f, 100.0f);
            igSliderFloat("movement speed", &MOVEMENT_SPEED, 0.0f, MAX_MOVEMENT_SPEED);
            igSliderFloat("jump height", &JUMP_HEIGHT, 0.0f, 64.0f);
            igSliderFloat("friction", &FRICTION, 0.0f, 2.0f);
            igInputFloat3("camera origin", camera.transform.origin, -1, ImGuiInputTextFlags_ReadOnly);
            igValueBool("crouching", Input.isActionPressed(PlayerActions.Crouch));
            igValueBool("sprinting", Input.isActionPressed(PlayerActions.Sprint));
            igValueBool("is on floor", isOnFloor);
            igValueFloat("camera pitch", rad2deg(pitch) % 360);
            igValueFloat("camera yaw", rad2deg(yaw) % 360);
            igValueBool("noclip enabled", g_noclip);
            igSliderFloat("noclip speed", &NOCLIP_SPEED, 1.0f, 40.0f);
            igValueFloat("collision safe margin", collisionSafeMargin);
            bool do_reset = igButton("reset player position");
            if (do_reset) transform = original_transform;
            igEnd();

        }
    }

    @Method
    void _physics_process(float delta) {

        auto vel = Vector3();
        if (g_noclip) velocity = Vector3.init;

        if (focused) {

            if (Input.isActionPressed(PlayerActions.Forwards)) {
                vel += Vector3(0, 0, -1) * MOVEMENT_SPEED;
            } else if (Input.isActionPressed(PlayerActions.Backwards)) {
                vel += Vector3(0, 0, 1) * MOVEMENT_SPEED;
            }

            if (Input.isActionPressed(PlayerActions.StrafeLeft)) {
                vel += Vector3(-1, 0, 0) * MOVEMENT_SPEED;
            }
            
            if (Input.isActionPressed(PlayerActions.StrafeRight)) {
                vel += Vector3(1, 0, 0) * MOVEMENT_SPEED;
            }

            if (Input.isActionJustPressed(PlayerActions.Jump) && isOnFloor()) {
                vel += Vector3(0, 1, 0) * JUMP_HEIGHT;
            } else if (Input.isActionPressed(PlayerActions.Jump) && g_noclip) {
                vel += Vector3(0, 1, 0) * JUMP_HEIGHT;
            } 

            if (Input.isActionJustPressed(PlayerActions.Crouch)) {
                camera.transform = Transform(camera.transform.basis, Vector3(0.0, 0.5, 0.0));
            } else if (Input.isActionJustReleased(PlayerActions.Crouch)) {
                camera.transform = Transform(camera.transform.basis, Vector3(0.0, 1.0, 0.0));
            }

            if (last_mouse_delta != Vector3.init) {

                auto t = transform;
                auto x_rot = last_mouse_delta.x / 200;
                yaw += x_rot;

                auto z_rot = last_mouse_delta.y / 200;
                pitch += z_rot;
                
                import std.math : PI_2;
                if (pitch > PI_2 - 0.001) {
                    pitch = PI_2 - 0.001;
                } else if (pitch < -PI_2 + 0.001) {
                    pitch = -PI_2 + 0.001;
                }

                if (g_noclip) {
                    rotation = Vector3(0, yaw, 0);
                    rotation = rotation + Vector3(pitch, 0, 0);
                    camera.rotation = Vector3.init;
                } else {
                    rotation = Vector3(0, yaw, 0);
                    camera.rotation = Vector3(pitch, 0, 0);
                }
                last_mouse_delta.x = 0;
                last_mouse_delta.y = 0;

            }

        }

        import std.algorithm : max, min;
        if (Input.isActionPressed(PlayerActions.Crouch)) vel *= 0.3;
        else if (Input.isActionPressed(PlayerActions.Sprint)) vel *= 1.5;
        auto clamped_velocity = min(MAX_MOVEMENT_SPEED, (vel + velocity).length);

        Vector3 clamped_combined;
        if (!isOnFloor && !g_noclip) {
            clamped_combined = (vel + velocity).normalized * clamped_velocity + Vector3(0, -1, 0) * GRAVITON;
        } else if (g_noclip) {
            clamped_combined = (vel + velocity).normalized * NOCLIP_SPEED;
        } else {
            clamped_combined = (vel + velocity).normalized * clamped_velocity;
        }

        moveAndSlide(transform.basis.orthonormalized.xform(clamped_combined), Vector3(0, 1, 0));
        velocity = clamped_combined;
        velocity.x /= FRICTION;
        velocity.z /= FRICTION;

        if (isOnFloor) velocity.y = 0;

    }

}