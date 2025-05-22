package main

import "core:fmt"
import "core:slice"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

Timeline :: struct {
	points: [dynamic]int,
	lines:  [dynamic]int,
	name:   cstring,
}

font: rl.Font
startIdx := 0

make_timeline :: proc(name: cstring) -> Timeline {
	return Timeline{name = name, points = make([dynamic]int), lines = make([dynamic]int)}
}

delete_timeline :: proc(t: ^Timeline) {
	delete(t.points)
	delete(t.lines)
}

tex_rect :: proc(t: rl.Texture) -> rl.Rectangle {
	return {0, 0, f32(t.width), f32(t.height)}
}

add_timeline :: proc(tl: ^[dynamic]Timeline, name: cstring) {
	append(tl, make_timeline(name))
}

has_idx :: proc(tl: []int, idx: int) -> int {
	for p, i in tl {
		if p == idx do return i
	}
	return -1
}

DrawTimelineEditor :: proc(tl: ^Timeline, pos: rl.Vector2) {
	pos := pos + {12, 0}
	if tl == nil do return
	idx := i32((pos.x - 96) / 24)
	if idx < 0 do return

	xPos := idx * 24 + 96
	yPos := i32(pos.y / 48) * 48
	if rl.IsMouseButtonPressed(.LEFT) {
		if i := has_idx(tl.points[:], int(idx)); i > -1 {
			ordered_remove(&tl.points, i)
		} else {
			append(&tl.points, int(idx))
			slice.sort(tl.points[:])
		}
	} else if rl.IsMouseButtonPressed(.RIGHT) {
		if i := has_idx(tl.lines[:], int(idx)); i > -1 {
			ordered_remove(&tl.lines, i)
		} else {
			append(&tl.lines, int(idx))
			slice.sort(tl.lines[:])
		}
	}

	rl.DrawLine(xPos, yPos, xPos, yPos + 48, rl.RED)
}

draw_vertical_dotted_line :: proc(
	x: f32,
	color: rl.Color = rl.GRAY,
	dash_length: i32 = 10,
	gap_length: i32 = 5,
) {
	screen_height := f32(rl.GetScreenHeight())
	current_y: f32 = 0

	drawing := true
	remaining := dash_length

	for current_y < screen_height {
		if drawing {
			end_y := min(current_y + f32(remaining), screen_height)
			rl.DrawLineV({x, current_y}, {x, end_y}, color)
			current_y = end_y
			remaining = gap_length
		} else {
			current_y += f32(remaining)
			remaining = dash_length
		}
		drawing = !drawing
	}
}

draw_grid :: proc() {
	x := 96
	w := cast(int)rl.GetScreenWidth()
	h := rl.GetScreenHeight()

	for x < w {
		defer x += 24
		rl.DrawLine(i32(x), 0, i32(x), h, rl.LIGHTGRAY)
	}
}

DrawTimeline :: proc(tl: ^Timeline, pos: rl.Vector2) {
	pos := pos + {2, 16}
	startingSide := false
	rl.DrawTextPro(font, tl.name, pos, {0, 0}, 0, 16, 1, rl.BLACK)
	points := make([dynamic]rl.Vector2)
	defer delete(points)
	append(&points, rl.Vector2{0, 1})
	for p in tl.points {
		if (!startingSide) {
			append(&points, rl.Vector2{f32(p), 1})
			append(&points, rl.Vector2{f32(p), 0})
		} else {
			append(&points, rl.Vector2{f32(p), 0})
			append(&points, rl.Vector2{f32(p), 1})
		}
		startingSide = !startingSide
	}
	pos -= {2, 16}
	for &p in points {
		p = p * rl.Vector2{24, 36} + rl.Vector2{96, pos.y + 6}
	}
	append(&points, rl.Vector2{1280, (startingSide ? 0 : 36) + pos.y + 6})
	rl.DrawLineStrip(raw_data(points[:]), cast(i32)len(points), rl.BLACK)
	for l in tl.lines {
		draw_vertical_dotted_line(f32(l * 24 + 96))
	}
}

main :: proc() {
	datebuf := [128]u8{}
	rl.InitWindow(1280, 768, "przebiegi")
	defer rl.CloseWindow()

	cam := rl.Camera2D {
		zoom = 1,
	}

	timelines := make([dynamic]Timeline)
	defer {
		for &t in timelines {
			delete_timeline(&t)
		}
		delete(timelines)
	}

	tex := rl.LoadRenderTexture(1280, 768)
	defer rl.UnloadRenderTexture(tex)

	font = rl.LoadFont("res/Roboto-VariableFont_wdth,wght.ttf")
	defer rl.UnloadFont(font)

	rect := tex_rect(tex.texture)
	inv_rect := rect
	inv_rect.height *= -1

	add_timeline(&timelines, "TRACKNUM")

	edited: ^Timeline
	takingScreenshot := false

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		{

			mousePos := rl.GetMousePosition()
			rl.ClearBackground(rl.WHITE)
			draw_grid()
			edited = nil
			for &tl, i in timelines {
				DrawTimeline(&tl, {0, f32(i) * 48})
				if int(mousePos.y / 48) == i {
					edited = &tl
				}
			}
			if !takingScreenshot do DrawTimelineEditor(edited, mousePos)
		}
		rl.EndDrawing()
		if takingScreenshot {
			takingScreenshot = false
			time_string := time.to_string_dd_mm_yyyy(time.now(), datebuf[:])
			str, err := strings.concatenate({time_string, ".png"})
			defer delete(str)
			if err != nil do return
			time_cstring := strings.clone_to_cstring(str)
			defer delete(time_cstring)
			rl.TakeScreenshot(time_cstring)
		}
		if rl.IsKeyPressed(.P) && !takingScreenshot {
			takingScreenshot = true
		}
	}
}
