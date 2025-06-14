extends CharacterBody2D


@export var speed := 300.0
@export var acceleration := 0.2
@export var friction := 0.15
@export var vida: int = 20
var estado_actual: Estado = Estado.NORMAL
var tiempo_invulnerabilidad: float = 0.8  # Segundos sin daño después de ser golpeado
enum Estado { NORMAL, INVULNERABLE, ATACANDO, MUERTO }
@onready var animated_sprite := $AnimatedSprite2D  # Asegúrate de que la ruta coincida con tu estructura de nodos
var last_direction := Vector2.DOWN# Dirección inicial por defecto (abajo)

 #1. DECLARACIÓN DE VARIABLES (arriba del todo)
#variablesde ataque 
@onready var raycast_ataque = $RayCast2D  # Asegúrate de añadir el nodo RayCast2D a tu escena

@export var rango_ataque: float = 100.0  # Pixeles de alcance
@export var dano_ataque: int = 1
@export var cooldown_ataque: float = 0.5
var puede_atacar: bool = true



func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		atacar()
# 2. FUNCIÓN _READY() - Configuración inicial
func _ready():

	# Inicialización del Timer de invulnerabilidad
	if not has_node("TimerInvulnerabilidad"):
		var timer = Timer.new()
		timer.name = "TimerInvulnerabilidad"
		timer.wait_time = tiempo_invulnerabilidad
		timer.timeout.connect(_on_invulnerabilidad_end)
		timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
		add_child(timer)
	
	#Verificación crítica de animaciones
	#assert($AnimationPlayer.has_animation("parpadeo_danado"),"Jugador inicializado correctamente")  # Para debug

# 3. FUNCIÓN CONEXA AL TIMER
func _on_invulnerabilidad_end():
	if estado_actual == Estado.INVULNERABLE:
		estado_actual = Estado.NORMAL
		modulate = Color.WHITE
		print("Fin de invulnerabilidad")  # Debug




func _physics_process(delta):
	if Input.is_action_just_pressed("atacar"):
		atacar()	
	# 1. Obtener input WASD
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. Calcular velocidad objetivo
	var target_velocity := direction * speed
	
	# 3. Interpolar suavemente
	velocity = velocity.lerp(target_velocity, acceleration if direction else friction)
	
	# 4. Mover y deslizar
	move_and_slide()
	# Actualizar la última dirección si hay movimiento
	if direction.length() > 0.1:
		last_direction = direction
	# 5. Controlar animaciones según la dirección
	handle_animations(direction)

func handle_animations(direction: Vector2):
	if direction.length() > 0.1:  # Si se está moviendo
		if abs(direction.x) > abs(direction.y):
			# Movimiento horizontal predominante
			if direction.x > 0:
				animated_sprite.play("run_derecha")
			else:
				animated_sprite.play("run_izquierda")
		else:
			# Movimiento vertical predominante
			if direction.y > 0:
				animated_sprite.play("run_down")
			else:
				animated_sprite.play("run_arriba")
	else:  # Animación idle (reposo)
		# Elegir idle según la última dirección
		if abs(last_direction.x) > abs(last_direction.y):  # Último movimiento fue horizontal
			if last_direction.x > 0:
				animated_sprite.play("rigth")
			else:
				animated_sprite.play("left")
		else:  # Último movimiento fue vertical
			if last_direction.y > 0:
				animated_sprite.play("down")
			else:
				animated_sprite.play("up")
				
func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(1)

# En el script del jugador (player.gd)
func recibir_dano(cantidad: int, direccion_empuje: Vector2 = Vector2.ZERO):
	# No recibir daño si ya está invulnerable o muerto
	if estado_actual == Estado.INVULNERABLE or estado_actual == Estado.MUERTO:
		return
	
	# Reducir vida
	vida -= cantidad
	print("Vida restante: ", vida)  # Para depuración
	
	# Efecto visual
	$AnimatedSprite2D.play("parpadeo_danado")
	modulate = Color(1, 0, 0, 0.7)  # Rojo semitransparente
	
	# Aplicar empuje (knockback)
	if direccion_empuje != Vector2.ZERO:
		velocity = direccion_empuje * 300
		move_and_slide()
	
	# Cambiar a estado invulnerable
	estado_actual = Estado.INVULNERABLE
	
	# Temporizador de invulnerabilidad
	await get_tree().create_timer(tiempo_invulnerabilidad).timeout
	
	# Volver a estado normal (si no está muerto)
	if vida > 0:
		modulate = Color.WHITE
		estado_actual = Estado.NORMAL
	else:
		morir()
		print("se murio alv ")

func morir():
	estado_actual = Estado.MUERTO
	$AnimationPlayer.play("muerte")
	modulate = Color(1, 0, 0)  # Rojo completo
	
	# Desactivar colisiones
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Notificar game over
	await $AnimationPlayer.animation_finished
	get_tree().reload_current_scene()  # O tu lógica de game over
	
	


func atacar():
	print("atacandoooo")
	if not puede_atacar:
		return
	
	# Obtener dirección del mouse (coordenadas globales a locales)
	var mouse_pos = get_global_mouse_position()
	var direccion_ataque = (mouse_pos - global_position).normalized()
	
	# Aplicar configuración al RayCast
	raycast_ataque.target_position = direccion_ataque * rango_ataque
	raycast_ataque.force_raycast_update()  # Actualizar detección inmediatamente
	
	# Animación basada en dirección (opcional)
	var angulo = rad_to_deg(direccion_ataque.angle())
	var anim_direccion = ""
	
	# Determinar animación según ángulo (ajusta según tus necesidades)
	if abs(angulo) <= 45:
		anim_direccion = "derecha"
	elif abs(angulo) >= 135:
		anim_direccion = "izquierda"
	elif angulo > 45 and angulo < 135:
		anim_direccion = "abajo"
	else:
		anim_direccion = "arriba"
	
	# Animación y sonido (descomenta cuando tengas los recursos)
	#$AnimatedSprite2D.play("ataque_" + anim_direccion)
	#$AudioAtaque.play()
	print("atacando hacia: ", anim_direccion)
	
	# Lógica de daño
	if raycast_ataque.is_colliding():
		var objetivo = raycast_ataque.get_collider()
		if objetivo.has_method("recibir_dano"):
			objetivo.recibir_dano(dano_ataque, global_position)
	
	# Cooldown
	puede_atacar = false
	await get_tree().create_timer(cooldown_ataque).timeout
	puede_atacar = true
