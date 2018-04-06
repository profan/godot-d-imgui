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
    Crouch = "player_crouch"
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

class Player : GodotScript!KinematicBody {

    float GRAVITON = 9.8f / 16; // 9.8 WHAT
    float MAX_MOVEMENT_SPEED = 18.0f; // SOME SHIT PER SECOND
    float MOVEMENT_SPEED = 1.5f; // .. what per second?
    float ACCELERATION = 10.0f;

    alias owner this;

    Vector3 velocity;
    Vector3 direction;
    Vector2 last_mouse_pos;
    Vector2 last_mouse_delta;

    bool focused = false;
    import std.math : PI_4;
    float yaw = 0.0f, pitch = 0.0f;

    @OnReady!"camera" Camera camera;
    @OnReady!"caster" RayCast caster;
    @OnReady!"collision" CollisionShape collision;

    @Method
    void _ready() {
    }

    @Method
    void _input(InputEvent ev) {

        if (InputEventMouseMotion mouse_ev = cast(InputEventMouseMotion)ev) {
            if (focused) {
                auto pos = mouse_ev.position;
                last_mouse_delta = last_mouse_pos - pos;
                last_mouse_pos = pos;
            }
        }

        if (InputEventKey key = cast(InputEventKey) ev) {
            if (key.isAction("ui_cancel")) {
                Input.setMouseMode(Input.MouseMode.mouseModeVisible);
                focused = !focused;
            }
        }

    }

    @Method
    void _process(float delta) {
        static bool showDemoWindow = true;
        import derelict.imgui.imgui;
        if (igGetFrameCount() > 0) {
            igBegin("Player");
            igInputFloat("gravity", &GRAVITON);
            igInputFloat("max movement speed", &MAX_MOVEMENT_SPEED);
            igInputFloat("movement speed", &MOVEMENT_SPEED);
            igEnd();
        }
    }

    @Method
    void _physics_process(float delta) {

        auto vel = Vector3();

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
                vel += Vector3(0, 1, 0) * 32.0f;
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

                rotation = Vector3(0, yaw, 0);
                camera.rotation = Vector3(pitch, 0, 0);
                last_mouse_delta.x = 0;
                last_mouse_delta.y = 0;

            }

        }

        import std.algorithm : max, min;
        auto clamped_velocity = min(MAX_MOVEMENT_SPEED, (vel + velocity).length);

        Vector3 clamped_combined;
        if (!isOnFloor) {
            clamped_combined = (vel + velocity).normalized * clamped_velocity + Vector3(0, -1, 0) * GRAVITON;
        } else {
            clamped_combined = (vel + velocity).normalized * clamped_velocity;
        }

        moveAndSlide(transform.basis.orthonormalized.xform(clamped_combined), Vector3(0, 1, 0));
        velocity = clamped_combined;
        velocity.x /= 1.2705;
        velocity.z /= 1.2705;

    }

}