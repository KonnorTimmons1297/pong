#import "Basic";
#import "Simp";
#import "Window_Creation";
#import "Input";
#import "Math";
#import "Random";
using Sound_Player :: #import "Sound_Player";

WINDOW_WIDTH := 800;
WINDOW_HEIGHT := 600;
PADDLE_WIDTH :: 15.0;
PADDLE_HEIGHT :: 150.0;
PADDLE_COLOR :: Vector4.{1, 1, 1, 1};
PADDLE_SPEED :: 300;
BALL_SIZE := 20.0;
BALL_SPEED := 200.0;

DeltaTime: float = 0.0;

THE_COLOR :: Vector4.{ 1, 1, 1, 1 };

MoveLeftPaddleUp := false;
MoveLeftPaddleDown := false;
MoveRightPaddleUp := false;
MoveRightPaddleDown := false;

LeftPaddlePos: Vector2;
RightPaddlePos: Vector2;
BallPos: Vector2;
BallVelocity: Vector2;
LeftScore: int = 0;
RightScore: int = 0;

sine_sound: Sound_Data;

GameStateE :: enum {
	Playing;
	Paused;
};

GameState := GameStateE.Paused;

DrawRectangle :: (position: Vector2, width: float, height: float) {
	bottom_left := position;
	bottom_right := Vector2.{ position.x + width, position.y };
	top_right := Vector2.{ position.x + width, position.y + height };
	top_left := Vector2.{ position.x, position.y + height };
	immediate_quad(
		bottom_left, bottom_right,
		top_right, top_left,
		THE_COLOR, THE_COLOR, THE_COLOR, THE_COLOR);
}

DrawBall :: (position: Vector2) {
	DrawRectangle(position, BALL_SIZE, BALL_SIZE);
}

DrawPaddle :: (position: Vector2) {
	DrawRectangle(position, PADDLE_WIDTH, PADDLE_HEIGHT);
}

MovePaddle :: (paddle_pos: *Vector2, move_up: bool, move_down: bool, DeltaTime: float) {
	if move_up paddle_pos.y += (PADDLE_SPEED * DeltaTime);
	if move_down paddle_pos.y -= (PADDLE_SPEED * DeltaTime);
	if paddle_pos.y <= 0 {
		paddle_pos.y = 0;
	}
	if (paddle_pos.y + PADDLE_HEIGHT) >= cast(float) WINDOW_HEIGHT {
		paddle_pos.y = WINDOW_HEIGHT - PADDLE_HEIGHT;
	}
}

ResetObjects :: () {
	distance_from_window_side := 15.0;
	LeftPaddlePos = Vector2.{ 
		distance_from_window_side, 
		(WINDOW_HEIGHT/2.0) - (PADDLE_HEIGHT/2.0)
	};
	RightPaddlePos = Vector2.{ 
		WINDOW_WIDTH - PADDLE_WIDTH - distance_from_window_side, 
		(WINDOW_HEIGHT/2.0) - (PADDLE_HEIGHT/2.0)
	};
	BallPos = Vector2.{
		(WINDOW_WIDTH/2.0) - (BALL_SIZE/2.0),
		(WINDOW_HEIGHT/2.0) - (BALL_SIZE/2.0)
	};
	BallVelocity = Vector2.{
		random_get_zero_to_one(), random_get_zero_to_one()
	};
	normalize(*BallVelocity);
}

UpdatePlayState :: () {
	for events_this_frame {
		if it.type == {
			case .KEYBOARD; {
				if it.key_code == .ARROW_UP {
					MoveRightPaddleUp = xx it.key_pressed;
				}
				if it.key_code == .ARROW_DOWN {
					MoveRightPaddleDown = xx it.key_pressed;
				}
				if it.key_code == #char "S" {
					MoveLeftPaddleUp = xx it.key_pressed;
				}
				if it.key_code == #char "X" { 
					MoveLeftPaddleDown = xx it.key_pressed;
				}
				if it.key_code == .ESCAPE {
					GameState = .Paused;

					// NOTE: Resetting these here because since they are global
					//       they can hold onto stale state that invalid after
					//       resuming.
					MoveRightPaddleUp = false;
					MoveRightPaddleDown = false;
					MoveLeftPaddleUp = false;
					MoveLeftPaddleDown = false;
				}
			}
		}
	}

	MovePaddle(*LeftPaddlePos, MoveLeftPaddleUp, MoveLeftPaddleDown, DeltaTime);
	MovePaddle(*RightPaddlePos, MoveRightPaddleUp, MoveRightPaddleDown, DeltaTime);

	BallPos += (BALL_SPEED * BallVelocity) * DeltaTime;
		
	intersected_with_right_paddle := 
		((BallPos.x + BALL_SIZE) >= RightPaddlePos.x) && 
		(BallPos.y >= RightPaddlePos.y) &&
		(BallPos.y <= (RightPaddlePos.y + PADDLE_HEIGHT));
	intersected_with_left_paddle := 
		(BallPos.x <= (LeftPaddlePos.x + PADDLE_WIDTH)) &&
		(BallPos.y >= LeftPaddlePos.y) &&
		(BallPos.y <= (LeftPaddlePos.y + PADDLE_HEIGHT));
		
	if intersected_with_left_paddle || intersected_with_right_paddle {
		BallVelocity.x *= -1.1;
		PlayBounce();
	}

	hit_wall := ((BallPos.y + BALL_SIZE) >= cast(float) WINDOW_HEIGHT) || BallPos.y <= 0;

	if hit_wall {
		BallVelocity.y *= -1;
		PlayBounce();
	}

	if BallPos.x >= cast(float) WINDOW_WIDTH {
		LeftScore += 1;
		ResetObjects();
		GameState = .Paused;
	}

	if BallPos.x <= 0 {
		RightScore += 1;
		ResetObjects();
		GameState = .Paused;
	}
}

UpdatePauseState :: () {
	for events_this_frame {
		if it.type == {
			case .KEYBOARD; {
				if it.key_code == #char " " {
					GameState = .Playing;
				}
			}
		}
	}
}

make_simple_sound :: (
	name: string, samples_per_second: u32, frequency: float, length_of_sound: float,
	gain: float
) -> Sound_Data {
	
	result: Sound_Data;
	
	result.name = name;
	result.type = .LINEAR_SAMPLE_ARRAY;
	result.sampling_rate = samples_per_second; // sample frequency
	
	result.nchannels = 1;
	
	// the number of samples in a second is constant. if you want to generate
	// a sound that is 1 second long and the sampling rate is 44100, then you
	// need to generate 44100 samples. Similarly, if you want generate a sound
	// that is 0.5 second long, then you need to generate 44100/2 samples. So,
	// samples_to_generate = sample_rate(in seconds) * length_of_sound
	
	samples_to_generate := cast(s64) (samples_per_second * length_of_sound); 
	
	result.nsamples_times_nchannels = samples_to_generate;
	sample_buffer := NewArray(samples_to_generate, s16);
	result.buffer  = string.{ samples_to_generate, cast(*u8) sample_buffer.data };
	result.samples = sample_buffer.data;
	
	wave_amplitude := 0xffff * gain;
	
	wave_cycles_per_sample_delta := frequency / samples_per_second;
	wave_sample_point := 0.0;
	for 0..samples_to_generate-1 {
		sample := cast(s16) (wave_amplitude * sin(wave_sample_point * TAU));
		sample_buffer[it] = sample;
		wave_sample_point += wave_cycles_per_sample_delta;
	}		
	
	return result;
}

PlayBounce :: () {
	stream := make_stream(*sine_sound);
	start_playing(stream);
}

main :: () {
	window := create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Pong!");	
	WINDOW_WIDTH, WINDOW_HEIGHT = get_render_dimensions(window);
	set_render_target(window);
	
	game_font := get_font_at_size("data", "W95FA.otf", 48);
	assert(game_font != null, "Couldn't load game font");
	
	success := sound_player_init(.{});
	assert(success);
	
	sine_sound = make_simple_sound(
		name = "sine", 
		samples_per_second = 44100,
		frequency = 600,
		length_of_sound = 0.1,
		gain = 0.25);
	
	ResetObjects();

	running : = true;
	while running {
		start_frame_time := current_time_monotonic();

		update_window_events();

		for events_this_frame {
			if it.type == .QUIT {
				running = false;
				break;
			}
		}
		if !running break;

		if GameState == {
			case .Playing; UpdatePlayState();
			case .Paused; UpdatePauseState();
		}

		clear_render_target(0, 0, 0, 1);
		set_shader_for_color();

		boundary_width := 2.0;
		DrawRectangle(
			Vector2.{ (WINDOW_WIDTH/2.0) - (boundary_width/2.0), 0 },
			boundary_width, cast(float) WINDOW_HEIGHT);
		
		DrawBall(BallPos);
		
		DrawPaddle(LeftPaddlePos);
		DrawPaddle(RightPaddlePos);

		LeftScore_text := tprint("%", LeftScore);
		LeftScore_text_width := prepare_text(game_font, LeftScore_text);
		LeftScore_text_x := (WINDOW_WIDTH/2) - LeftScore_text_width - 5;
		LeftScore_text_y := WINDOW_HEIGHT - game_font.character_height - 5;
		draw_prepared_text(game_font, LeftScore_text_x, LeftScore_text_y, THE_COLOR);

		RightScore_text := tprint("%", RightScore);
		RightScore_text_width := prepare_text(game_font, RightScore_text);
		RightScore_text_x := (WINDOW_WIDTH/2) + 5;
		RightScore_text_y := WINDOW_HEIGHT - game_font.character_height - 5;
		draw_prepared_text(game_font, RightScore_text_x, RightScore_text_y, THE_COLOR);

		if GameState == .Paused {
			prompt_play_text := "Press Space to Play!";

        	text_width := prepare_text(game_font, prompt_play_text);

        	text_x := (WINDOW_WIDTH - text_width) / 2;
        	text_y := WINDOW_HEIGHT/4 + game_font.character_height/4;

        	draw_prepared_text(game_font, text_x, text_y, THE_COLOR);
		}

		Sound_Player.update();
		
		swap_buffers(window);

		reset_temporary_storage();

		end_frame_time := current_time_monotonic();
		frame_time := end_frame_time - start_frame_time;
		DeltaTime = to_microseconds(frame_time) / 1_000_000.0;
	}

    sound_player_shutdown();
}
