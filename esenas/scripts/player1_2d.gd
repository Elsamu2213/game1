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
	if estado_actual != Estado.NORMAL:
		return
	
	estado_actual = Estado.ATACANDO
	$AnimationPlayer.play("ataque")
	await $AnimationPlayer.animation_finished
	estado_actual = Estado.NORMAL
