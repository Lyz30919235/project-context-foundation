extends Control
const INK=Color("#2c4035")
const MUTED=Color("#87947b")
const ORANGE=Color("#cb7c47")
const PAPER=Color("#fbf9f1")
var font: Font=preload("res://assets/NotoSansCJKsc-Regular.otf")
var map: NativeMapData
var state: NativeRules
var world: NativeWorld
var nav: NativeNavigation
var board: SubViewportContainer
var viewport: SubViewport
var minimap: Control
var stars_label: Label
var stars_icons: Label
var keys_label: Label
var elapsed_label: Label
var steps_label: Label
var status_label: Label
var zoom_label: Label
var toast_label: Label
var intro: PanelContainer
var modal: ColorRect
var modal_title: Label
var modal_body: Label
var modal_buttons: HBoxContainer
var progress: ProgressBar
var camera_zoom=1.0
var following=false
var active=false
var paused=false
var ready_game=false
var elapsed=0.0
var save_clock=0.0
var hud_clock=0.0
var toast_clock=0.0
var blocked_clock=0.0
var speed=110.0
var save_path="user://native-save.json"
func _ready():
	get_tree().auto_accept_quit=false
	if "--qa" in OS.get_cmdline_user_args():
		save_path="user://qa-native-save.json"
	if "--verify-package" in OS.get_cmdline_user_args():
		save_path="user://packaged-runtime-test.json"
	var theme_resource=Theme.new()
	theme_resource.default_font=font
	theme_resource.default_font_size=14
	theme=theme_resource
	_build_ui()
	_setup_input()
	await get_tree().process_frame
	map=NativeMapData.new()
	state=NativeRules.new(map)
	_restore()
	world=NativeWorld.new()
	viewport.add_child(world)
	world.configure(map,state)
	world.player.speed=speed
	world.player.events_fired.connect(_events)
	nav=NativeNavigation.new(map,state)
	board.camera=world.camera
	minimap.world=world
	ready_game=true
	viewport.size_changed.connect(_resized)
	await get_tree().process_frame
	if active:
		intro.hide()
		_locate()
	else:
		_fit()
	_refresh_hud()
	status_label.text="探索进度会自动保存"
	if state.won:
		_win()
	if "--verify-package" in OS.get_cmdline_user_args():
		call_deferred("_verify_package")
func panel(color: Color,radius: int=8) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	return style
func text_label(text: String,size: int=14,color: Color=INK) -> Label:
	var label=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label
func button(text: String,action: Callable,primary: bool=false) -> Button:
	var b=Button.new()
	b.text=text
	b.focus_mode=Control.FOCUS_NONE
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y=36
	b.add_theme_stylebox_override("normal",panel(INK if primary else Color("#f8f9ef"),6))
	b.add_theme_stylebox_override("hover",panel(Color("#496247") if primary else Color("#e6ecda"),6))
	b.add_theme_stylebox_override("pressed",panel(Color("#5a7051") if primary else Color("#dbe5ce"),6))
	b.add_theme_color_override("font_color",PAPER if primary else Color("#738868"))
	b.add_theme_color_override("font_hover_color",PAPER if primary else INK)
	b.add_theme_constant_override("outline_size",0)
	b.pressed.connect(action)
	return b
func separator(parent: Control):
	var line=HSeparator.new()
	line.add_theme_color_override("separator_color",Color("#e2e7d5"))
	parent.add_child(line)
func section(parent: Control,title: String) -> Label:
	var label=text_label(title,14,INK)
	parent.add_child(label)
	return label
func _build_ui():
	var background=ColorRect.new()
	background.color=Color("#f2f4eb")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var row=HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation",0)
	add_child(row)
	var side=PanelContainer.new()
	side.custom_minimum_size.x=268
	side.add_theme_stylebox_override("panel",panel(PAPER,0))
	row.add_child(side)
	var margin=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",25)
	margin.add_theme_constant_override("margin_right",25)
	margin.add_theme_constant_override("margin_top",24)
	margin.add_theme_constant_override("margin_bottom",18)
	side.add_child(margin)
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",11)
	margin.add_child(column)
	column.add_child(text_label("✳ map.",48,INK))
	column.add_child(text_label("手绘迷宫  /  WINDOWS",11,MUTED))
	var heading=text_label("把星光，\n带出迷宫。",29,INK)
	heading.custom_minimum_size.y=92
	column.add_child(heading)
	column.add_child(text_label("沿着纸上的曲折前行，\n拐个弯，也没关系。",12,MUTED))
	separator(column)
	stars_label=section(column,"收集星光                     0 / 4")
	stars_icons=text_label("✦  ✦  ✦  ✦",30,Color("#dfe4d4"))
	column.add_child(stars_icons)
	progress=ProgressBar.new()
	progress.custom_minimum_size.y=5
	progress.show_percentage=false
	progress.add_theme_stylebox_override("background",panel(Color("#e6eadc"),2))
	progress.add_theme_stylebox_override("fill",panel(Color("#cda052"),2))
	column.add_child(progress)
	column.add_child(text_label("集齐所有星星，终点才会开启。",11,MUTED))
	keys_label=section(column,"我的钥匙                      0 / 5")
	separator(column)
	column.add_child(text_label("↗  传1 → 传2 → 传3 → 传4 → 传5",11,Color("#637e56")))
	column.add_child(text_label("编号钥匙开门，钥匙保留。\n问号是空的，没有隐藏物品。",12,MUTED))
	var speed_row=HBoxContainer.new()
	column.add_child(speed_row)
	speed_row.add_child(text_label("步速",12,MUTED))
	var slider=HSlider.new()
	slider.min_value=60
	slider.max_value=180
	slider.step=10
	slider.value=110
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.tooltip_text="调整行走速度，默认 110"
	slider.focus_mode=Control.FOCUS_NONE
	slider.value_changed.connect(func(value):speed=value;if ready_game:world.player.speed=speed)
	speed_row.add_child(slider)
	var spacer=Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	section(column,"你在这里")
	minimap=load("res://scripts/minimap.gd").new()
	minimap.custom_minimum_size.y=135
	minimap.selected.connect(_mini_selected)
	column.add_child(minimap)
	status_label=text_label("正在展开地图……",11,MUTED)
	column.add_child(status_label)
	var main=VBoxContainer.new()
	main.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",0)
	row.add_child(main)
	var top=HBoxContainer.new()
	top.custom_minimum_size.y=68
	top.add_theme_constant_override("separation",14)
	main.add_child(top)
	var top_margin=Control.new()
	top_margin.custom_minimum_size.x=8
	top.add_child(top_margin)
	top.add_child(text_label("●  纸上迷宫",15,Color("#70875c")))
	var top_spacer=Control.new()
	top_spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	elapsed_label=text_label("00:00",17,INK)
	top.add_child(elapsed_label)
	steps_label=text_label("0 步",12,MUTED)
	top.add_child(steps_label)
	top.add_child(button("暂停",_toggle_pause))
	top.add_child(button("玩法",_help))
	var outer=MarginContainer.new()
	outer.add_theme_constant_override("margin_left",18)
	outer.add_theme_constant_override("margin_right",18)
	outer.add_theme_constant_override("margin_bottom",6)
	outer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main.add_child(outer)
	var stage=PanelContainer.new()
	stage.add_theme_stylebox_override("panel",panel(Color("#e9eddf"),10))
	outer.add_child(stage)
	var layer=Control.new()
	layer.custom_minimum_size=Vector2(600,400)
	stage.add_child(layer)
	board=load("res://scripts/board.gd").new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.stretch=true
	layer.add_child(board)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1000,700)
	viewport.transparent_bg=true
	viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	board.add_child(viewport)
	board.destination.connect(_go_to)
	board.pan_requested.connect(_pan)
	board.zoom_requested.connect(_zoom)
	var note=text_label("01  /  每条弯路都值得探索",11,Color("#8c9d7b"))
	note.position=Vector2(18,14)
	note.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(note)
	var tools=HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tools.position=Vector2(15,-54)
	layer.add_child(tools)
	tools.add_child(button("−",func():_zoom(.8,board.size/2)))
	zoom_label=text_label("全图",12,MUTED)
	zoom_label.custom_minimum_size=Vector2(40,32)
	zoom_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	tools.add_child(zoom_label)
	tools.add_child(button("＋",func():_zoom(1.25,board.size/2)))
	tools.add_child(button("全图 F",_fit))
	tools.add_child(button("定位 C",_locate))
	tools.add_child(button("一点提示",_hint))
	toast_label=text_label("",13,PAPER)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_top=-100
	toast_label.offset_bottom=-65
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal",panel(Color("#334a39ef"),6))
	toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_label)
	toast_label.hide()
	intro=PanelContainer.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	intro.offset_left=-323
	intro.offset_top=-245
	intro.offset_right=-26
	intro.offset_bottom=-82
	var card_style=panel(Color("#fcfaf2f5"),11)
	card_style.content_margin_left=22
	card_style.content_margin_right=22
	card_style.content_margin_top=20
	card_style.content_margin_bottom=20
	intro.add_theme_stylebox_override("panel",card_style)
	layer.add_child(intro)
	var intro_col=VBoxContainer.new()
	intro_col.add_theme_constant_override("separation",11)
	intro.add_child(intro_col)
	intro_col.add_child(text_label("你的探索，即将开始",11,MUTED))
	intro_col.add_child(text_label("一张纸，很多条可能。",20,INK))
	intro_col.add_child(text_label("找到全部星星，再走向右下角终点。",11,MUTED))
	intro_col.add_child(button("开始探索  ↗",_start,true))
	var footer=HBoxContainer.new()
	footer.custom_minimum_size.y=42
	main.add_child(footer)
	var help_text=text_label("    WASD / 方向键移动 · 点击道路寻路 · 右键拖动 · 滚轮缩放 · 空格暂停",11,MUTED)
	help_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(help_text)
	footer.add_child(button("重新开始",_confirm_restart))
	modal=ColorRect.new()
	modal.color=Color("#20352670")
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var modal_panel=PanelContainer.new()
	modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal_panel.offset_left=-265
	modal_panel.offset_right=265
	modal_panel.offset_top=-210
	modal_panel.offset_bottom=210
	var modal_style=panel(PAPER,14)
	modal_style.content_margin_left=32
	modal_style.content_margin_right=32
	modal_style.content_margin_top=30
	modal_style.content_margin_bottom=26
	modal_panel.add_theme_stylebox_override("panel",modal_style)
	modal.add_child(modal_panel)
	var modal_column=VBoxContainer.new()
	modal_column.add_theme_constant_override("separation",20)
	modal_panel.add_child(modal_column)
	modal_title=text_label("",28,INK)
	modal_column.add_child(modal_title)
	modal_body=text_label("",14,MUTED)
	modal_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	modal_body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	modal_column.add_child(modal_body)
	modal_buttons=HBoxContainer.new()
	modal_buttons.alignment=BoxContainer.ALIGNMENT_END
	modal_buttons.add_theme_constant_override("separation",10)
	modal_column.add_child(modal_buttons)
	modal.hide()
func _setup_input():
	var actions={"map_left":[KEY_A,KEY_LEFT],"map_right":[KEY_D,KEY_RIGHT],"map_up":[KEY_W,KEY_UP],"map_down":[KEY_S,KEY_DOWN]}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in actions[action]:
			var event=InputEventKey.new()
			event.physical_keycode=code
			InputMap.action_add_event(action,event)
func _physics_process(delta: float):
	if not ready_game or not active or paused:
		return
	var direction=Input.get_vector("map_left","map_right","map_up","map_down")
	if direction.length_squared()>.001:
		following=true
	world.player.advance(direction,delta)
	elapsed+=delta
func _process(delta: float):
	if not ready_game:
		return
	hud_clock+=delta
	save_clock+=delta
	blocked_clock=maxf(0,blocked_clock-delta)
	if hud_clock>.1:
		hud_clock=0
		_refresh_hud()
	if save_clock>3:
		save_clock=0
		_save()
	if toast_clock>0:
		toast_clock-=delta
		if toast_clock<=0:
			toast_label.hide()
	if following:
		world.camera.position=_clamped_center(world.player.position)
func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not ready_game:
		return
	if event.keycode==KEY_F:
		_fit()
	elif event.keycode==KEY_C:
		_locate()
	elif event.keycode in [KEY_SPACE,KEY_ESCAPE]:
		_toggle_pause()
	elif event.keycode==KEY_F11:
		var mode=DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not active and event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		_start()
func _notification(what: int):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and ready_game:
		_release_input()
		if active and not state.won:
			_pause()
		_save()
func _release_input():
	for action in ["map_left","map_right","map_up","map_down"]:
		Input.action_release(action)
	if board!=null:
		board.dragging=false
func _clamped_center(p: Vector2) -> Vector2:
	var half=Vector2(viewport.size)/(2*camera_zoom)
	return Vector2(map.width*.5 if map.width<half.x*2 else clampf(p.x,half.x,map.width-half.x),map.height*.5 if map.height<half.y*2 else clampf(p.y,half.y,map.height-half.y))
func _resized():
	if not ready_game:
		return
	if following:
		_locate()
	elif not active:
		_fit()
	else:
		world.camera.position=_clamped_center(world.camera.position)
func _fit():
	if not ready_game:
		return
	camera_zoom=minf((viewport.size.x-55.0)/map.width,(viewport.size.y-45.0)/map.height)
	world.camera.zoom=Vector2.ONE*camera_zoom
	world.camera.position=Vector2(map.width,map.height)*.5
	world.camera.reset_smoothing()
	following=false
	zoom_label.text="全图"
func _locate():
	if not ready_game:
		return
	camera_zoom=2.8
	world.camera.zoom=Vector2.ONE*camera_zoom
	world.camera.position=_clamped_center(world.player.position)
	world.camera.reset_smoothing()
	following=true
	zoom_label.text="140%"
func _pan(delta: Vector2):
	if not ready_game:
		return
	following=false
	world.camera.position=_clamped_center(world.camera.position-delta/camera_zoom)
	world.camera.reset_smoothing()
func _zoom(factor: float,at: Vector2):
	if not ready_game:
		return
	var before=viewport.get_canvas_transform().affine_inverse()*at
	var minimum=minf(viewport.size.x/float(map.width),viewport.size.y/float(map.height))*.8
	camera_zoom=clampf(camera_zoom*factor,minimum,8.0)
	world.camera.zoom=Vector2.ONE*camera_zoom
	var after=viewport.get_canvas_transform().affine_inverse()*at
	world.camera.position=_clamped_center(world.camera.position+before-after)
	world.camera.reset_smoothing()
	following=false
	zoom_label.text=str(roundi(camera_zoom*50))+"%"
func _mini_selected(p: Vector2):
	if not ready_game:
		return
	camera_zoom=maxf(1.5,camera_zoom)
	world.camera.zoom=Vector2.ONE*camera_zoom
	world.camera.position=_clamped_center(p)
	world.camera.reset_smoothing()
	following=false
func _start():
	if not ready_game:
		return
	active=true
	paused=false
	world.player.paused=false
	intro.hide()
	modal.hide()
	_locate()
	_toast("从左下角出发。按方向移动，也可以点击道路前往。")
func _go_to(p: Vector2):
	if not ready_game or paused or state.won:
		return
	if not active:
		_start()
	var path=nav.path_to(p)
	if path.is_empty():
		_toast("暂时走不到这里，试试其他道路、钥匙或传送点。")
	else:
		world.player.set_route(path)
		following=true
func _hint():
	if not ready_game or state.won:
		return
	if not active:
		_start()
	if paused:
		return
	var targets=[]
	for item in state.level.keys:
		if not state.keys.has(str(item.id)):
			targets.append(item)
	for item in state.level.stars:
		if not state.stars.has(str(item.id)):
			targets.append(item)
	if state.all_stars():
		targets=[state.level.goal]
	else:
		targets.append_array(state.level.portals.slice(0,4))
	targets.sort_custom(func(a,b):return map.point(a).distance_squared_to(state.position)<map.point(b).distance_squared_to(state.position))
	var best=PackedVector2Array()
	for target in targets:
		var path=nav.path_to(map.point(target))
		if path.size()>5 and (best.is_empty() or path.size()<best.size()):
			best=path
		if best.size()>5 and best.size()<500:
			break
	if best.is_empty():
		_toast("先在附近找找岔路，或尝试传送点。")
	else:
		world.player.set_route(best.slice(0,mini(110,best.size())))
		following=true
		_toast("照亮前方的一小段，剩下的路由你发现。")
func _events(events: Array):
	var access_changed=false
	for event in events:
		match event.type:
			"star":
				_toast("星光已集齐！去右下角的终点吧。" if state.all_stars() else "找到一颗星星 · %d / %d"%[state.stars.size(),state.level.stars.size()])
			"key":
				_toast("找到钥匙 "+str(event.id)+"，可以打开对应的门。")
				access_changed=true
			"door":
				_toast("门已打开，钥匙仍保留。")
				access_changed=true
			"question":
				_toast("问号是空的，这里没有物品。")
			"portal":
				_toast("传%d → 传%d · 已到达新位置"%[event.from,event.to])
				_locate()
			"locked":
				_blocked("这扇门还需要对应的钥匙。")
			"goalLocked":
				_blocked("终点还未开启，请先集齐星星。")
			"routeBlocked":
				_blocked("这里需要转个弯，可以用方向键调整。")
			"win":
				_win()
	if access_changed and nav!=null:
		nav.refresh_access()
func _blocked(text: String):
	if blocked_clock<=0:
		blocked_clock=2
		_toast(text)
func _toast(text: String):
	toast_label.text=text
	toast_label.show()
	toast_clock=3.0
func _refresh_hud():
	stars_label.text="收集星光                     %d / %d"%[state.stars.size(),state.level.stars.size()]
	var icons=""
	for item in state.level.stars:
		icons+="✦ " if state.stars.has(str(item.id)) else "☆ "
	stars_icons.text=icons
	stars_icons.add_theme_color_override("font_color",Color("#c89b42") if not state.stars.is_empty() else Color("#cfd8bf"))
	progress.value=float(state.stars.size())/state.level.stars.size()*100
	var key_text=""
	for item in state.level.keys:
		key_text+=(" %s "%item.id) if state.keys.has(str(item.id)) else " · "
	keys_label.text="钥匙  "+key_text
	elapsed_label.text="%02d:%02d"%[int(elapsed)/60,int(elapsed)%60]
	steps_label.text="%d 步"%roundi(state.distance)
func _show_modal(title: String,body: String,actions: Array):
	paused=true
	world.player.paused=true
	world.player.cancel_route()
	_release_input()
	modal_title.text=title
	modal_body.text=body
	for child in modal_buttons.get_children():
		child.queue_free()
	for action in actions:
		modal_buttons.add_child(button(action[0],action[1],action.size()>2 and action[2]))
	modal.show()
func _pause():
	_show_modal("迷宫会在这里等你。","暂停时不会继续移动或计时。探索进度会自动保存。",[["继续探索",_resume,true],["查看玩法",_help],["退出游戏",func():_save();get_tree().quit()]])
	_save()
func _resume():
	paused=false
	world.player.paused=false
	modal.hide()
func _toggle_pause():
	if not ready_game:
		return
	if state.won:
		return
	if not active:
		_start()
	elif paused:
		_resume()
	else:
		_pause()
func _help():
	if not ready_game:
		return
	_show_modal("沿着你的节奏探索。","星星：全部收齐后才能进入终点。\n钥匙：编号相同才能开门，多编号门需同时持有对应钥匙。\n传送：传 n 到传 n+1，落地先离开再进入才会继续；传5是最终落点。\n问号：没有物品。\n\nWASD / 方向键移动；点击道路寻路；右键或中键拖动地图；滚轮缩放。\nF 全图，C 定位，空格 / Esc 暂停，F11 全屏。\n\n手绘原稿的模糊门编号及终点位置沿用暂定设定。",[["开始 / 继续",func():if not active:_start()
	else:_resume(),true]])
func _confirm_restart():
	if not ready_game:
		return
	_show_modal("要从头探索吗？","本次收集和行走进度会清空。",[["保留进度",_resume],["重新开始",_restart,true]])
func _restart():
	state=NativeRules.new(map)
	world.state=state
	world.player.state=state
	world.player.position=state.position
	world.player.cancel_route()
	world.sync_doors()
	nav=NativeNavigation.new(map,state)
	world.visual.trail=PackedVector2Array()
	elapsed=0
	active=false
	paused=false
	world.player.paused=false
	modal.hide()
	intro.show()
	_fit()
	_refresh_hud()
	_save()
func _win():
	_show_modal("所有星光，都找到了。","你走出了这张迷宫。\n\n收集 %d 颗星星 · 用时 %02d:%02d · 走过 %d 步"%[state.stars.size(),int(elapsed)/60,int(elapsed)%60,roundi(state.distance)],[["再看看地图",func():modal.hide();paused=true;_fit()],["再走一次",_restart,true]])
	_save()
func _save():
	if not ready_game:
		return
	var file=FileAccess.open(save_path,FileAccess.WRITE)
	if file==null:
		status_label.text="保存暂不可用，仍可继续探索"
		return
	file.store_string(JSON.stringify({"state":state.snapshot(),"elapsed":elapsed,"active":active,"speed":speed}))
	status_label.text="探索进度已自动保存"
func _restore():
	if not FileAccess.file_exists(save_path):
		return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary and data.get("state") is Dictionary and state.restore(data.state):
		elapsed=maxf(0,float(data.get("elapsed",0)))
		active=bool(data.get("active",false))
		speed=clampf(float(data.get("speed",110)),60,180)
func _verify_package():
	# This isolated check is used by the release script, never by normal play.
	state=NativeRules.new(map)
	state.keys["2"]=true
	elapsed=42
	_save()
	state=NativeRules.new(map)
	elapsed=0
	_restore()
	var ok=map.walls.size()>0 and map.centers.size()==map.width*map.height*4 and nav.astar.get_point_count()>1000 and world.get_child_count()>80 and font.has_char(0x8ff7) and state.keys.has("2") and elapsed==42
	var report={"ok":ok,"map":[map.width,map.height],"navigation_nodes":nav.astar.get_point_count(),"font_chinese":font.has_char(0x8ff7),"save_restore":state.keys.has("2") and elapsed==42,"engine":Engine.get_version_info().string,"license_text":Engine.get_license_text()}
	var report_path=OS.get_environment("MAP_VERIFY_REPORT")
	if report_path!="":
		var output=FileAccess.open(report_path,FileAccess.WRITE)
		if output!=null:
			output.store_string(JSON.stringify(report))
	print("MAP_PACKAGE_VERIFICATION ",JSON.stringify(report))
	get_tree().quit(0 if ok else 1)
