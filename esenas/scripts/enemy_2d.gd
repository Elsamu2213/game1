extends CharacterBody2D
enum Estado { IDLE, ALERTA, PERSEGUIR, ATAQUE, DANADO, MUERTO }
var estado_actual: Estado = Estado.IDLE
var updating_animations: bool = false
@export var dano_base: int = 1  # Daño que aplicará el enemigo
@export var fuerza_empuje: float = 9000.0  # Fuerza de retroceso

@onready var attack_area: Area2D = $AttackArea
# Añade estas variables en la sección de variables del script
@export var vida: int = 3
 # Velocidad al rodear
@export var tiempo_invulnerabilidad: float = 0.5

var puede_cambiar_estado: bool = true


@export var attack_range: float = 70.0  # Rango óptimo de ataque
@export var cooldown_ataque: float = 7.5  # Tiempo entre ataques
@export var margen_salida_ataque: float = 1.3  # 1.3x el attack_range para salir

# === CONFIGURACIÓN EXPORTADA ===
@export var speed: float = 150.0 #valoccidad del enemigo
@export var acceleration: float = 0.5
@export var detection_radius: float = 300.0

# === REFERENCIAS A NODOS ===
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
var player: CharacterBody2D = null  # Referencia al jugador


# === VARIABLES ===
var last_direction: Vector2 = Vector2.DOWN  # Dirección inicial para animaciones idle

func _ready():
	# Configura el radio del área de detección (opcional)
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	detection_area.get_node("CollisionShape2D").shape = shape
	
	# Conecta señales automáticamente 
	detection_area.body_entered.connect(_on_body_entered)#activa el metodo _on_body_entered cuando el personaje entra
	detection_area.body_exited.connect(_on_body_exited)#activa el metodo _on_body_entered cuando el personaje Sale de l AREA

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):  # Asegúrate de que tu jugador tenga el grupo "player"
		player = body
		print("Jugador detectado!")

func _on_body_exited(body: Node2D):
	if body == player:
		player = null
		print("Jugador perdido")
		


func _physics_process(delta: float):
	
	if not puede_cambiar_estado:
		return
	
	match estado_actual:
		Estado.IDLE:
			comportamiento_idle()
		Estado.ALERTA:
			comportamiento_alerta()
		Estado.PERSEGUIR:
			comportamiento_perseguir()
		Estado.ATAQUE:
			comportamiento_ataque()
		Estado.DANADO:
			comportamiento_danado()
		#Estado.MUERTO:
			#comportamiento_muerto()
	
	move_and_slide()
	


#== COMPORTAMIENTOS DEL ENEMIGO=
func comportamiento_idle():
	velocity = velocity.lerp(Vector2.ZERO, 0.2)
	update_animations(Vector2.ZERO)
	
	# Transición a ALERTA si detecta jugador
	if player and global_position.distance_to(player.global_position) < detection_radius:
		cambiar_estado(Estado.ALERTA)

func comportamiento_alerta():
	if not is_instance_valid(player):
		cambiar_estado(Estado.IDLE)
		return
	
	var distancia = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()
	update_animations(direction)
	
	# Lógica de transición mejorada
	if distancia > detection_radius * 1.2:  # Margen del 20% para evitar oscilaciones
		cambiar_estado(Estado.IDLE)
	elif distancia < detection_radius * 0.8:  # Entrar en persecución antes
		print("cambiando5")
		cambiar_estado(Estado.PERSEGUIR)
	else:
		# Comportamiento de alerta (mirar al jugador sin moverse)
		velocity = velocity.lerp(Vector2.ZERO, 0.1)
func comportamiento_perseguir():
	if not is_instance_valid(player):
		cambiar_estado(Estado.IDLE)
		return
	
	var to_player = player.global_position - global_position
	var distancia = to_player.length()
	var direction = to_player.normalized()
	
	# Movimiento con distancia de seguridad
	if distancia > attack_range * 1.1:  # Perseguir normal
		var target_velocity = direction * speed
		velocity = velocity.lerp(target_velocity, acceleration)
	else:  # Frenar al acercarse al rango de ataque
		velocity = velocity.lerp(direction * speed * 0.3, acceleration)
	
	# Transiciones mejoradas con histéresis
	if distancia > detection_radius * 1.5:
		cambiar_estado(Estado.ALERTA)
	elif distancia < attack_range * 0.9:  # 10% de margen para ataque
		cambiar_estado(Estado.ATAQUE)
	
	update_animations(direction)

func comportamiento_ataque():
	# Validación esencial del jugador
	if not is_instance_valid(player):
		cambiar_estado(Estado.IDLE)
		return
	
	# Calcular distancia actual
	var distancia = global_position.distance_to(player.global_position)
	
	# Condición de salida: jugador demasiado lejos
	await animated_sprite.frame_changed
	if animated_sprite.frame == 9:
		cambiar_estado(Estado.PERSEGUIR)
		return
	
	# Detener movimiento durante el ataque
	velocity = Vector2.ZERO
	
	# Reproducir animación de ataque (con validación)
	if animated_sprite.sprite_frames.has_animation("ataque"):
		animated_sprite.play("ataque")
		
		
	else:
		push_warning("Falta animación 'ataque'")
		print("cambiando2")
		cambiar_estado(Estado.PERSEGUIR)
		return
	
	# Aplicar daño en el frame adecuado
	await animated_sprite.frame_changed
	if animated_sprite.frame == 9:  # Ajusta al frame de impacto
		aplicar_dano_al_jugador()
	
	# Esperar a que termine la animación completa
	await animated_sprite.animation_finished
	
	# Decisión post-ataque
	if not is_instance_valid(player):
		print("cambio")
		cambiar_estado(Estado.IDLE)
	else:
		# Verificar si el jugador sigue en rango
		var nueva_distancia = global_position.distance_to(player.global_position)
		if nueva_distancia > attack_range * 1.1:
			print("cambiando3")
			cambiar_estado(Estado.PERSEGUIR)
		else:
			# Cooldown entre ataques
			await get_tree().create_timer(0.5).timeout
			if estado_actual == Estado.ATAQUE:  # Verificar que no cambió de estado
				comportamiento_ataque()
func _on_detection_area_body_exited(body):
	if body == player:
		# Forzar salida del estado de ataque
		if estado_actual == Estado.ATAQUE:
			cambiar_estado(Estado.ALERTA)
		
		# Temporizador de olvido (si el jugador no regresa)
		await get_tree().create_timer(2.0).timeout
		if estado_actual == Estado.ALERTA and not is_instance_valid(player):
			cambiar_estado(Estado.IDLE)
			
func aplicar_dano_al_jugador():
	# 1. Validación exhaustiva del jugador
	if not is_instance_valid(player):
		push_warning("Intento de daño a jugador no válido")
		return
	
	# 2. Verificar distancia y línea de visión
	var distancia = global_position.distance_to(player.global_position)
	if distancia > attack_range * 1.1:  # 10% más de margen
		return
	
	# 3. Verificar si el jugador puede recibir daño
	if not player.has_method("recibir_dano"):
		push_error("El jugador no tiene método 'recibir_dano'")
		return
	
	# 4. Efectos visuales/sonido (con validación)
	if has_node("Particles2D"):
		$Particles2D.emitting = true  # Efecto de golpe
	if has_node("AudioAtaque"):
		$AudioAtaque.play()  # Sonido de ataque
	
	# 5. Aplicar daño y empuje (knockback)
	var direccion_empuje = (player.global_position - global_position).normalized()
	player.call("recibir_dano", dano_base, direccion_empuje)  # Versión segura
func comportamiento_danado():
	velocity = velocity.lerp(Vector2.ZERO, 0.3)
	animated_sprite.play("danado")
	modulate = Color(1, 0.5, 0.5)  # Efecto visual
	
	# Esperar tiempo de invulnerabilidad
	await get_tree().create_timer(tiempo_invulnerabilidad).timeout
	
	# Transición según condiciones
	if vida <= 0:
		cambiar_estado(Estado.MUERTO)
	elif is_instance_valid(player):
		var distancia = global_position.distance_to(player.global_position)
		if distancia < attack_range:
			cambiar_estado(Estado.ATAQUE)
		else:
			print("cambiando4")
			cambiar_estado(Estado.PERSEGUIR)
	else:
		cambiar_estado(Estado.IDLE)
	
	modulate = Color.WHITE  # Restaurar color
		
func recibir_dano(cantidad: int):
	# No recibir daño si ya está en estado vulnerable
	if estado_actual == Estado.DANADO or estado_actual == Estado.MUERTO:
		return
	
	vida -= cantidad
	
	# Feedback visual inmediato
	$HitParticles.emitting = true  # Si tienes partículas
	
	if vida <= 0:
		cambiar_estado(Estado.MUERTO)
	else:
		cambiar_estado(Estado.DANADO)

func cambiar_estado(nuevo_estado: Estado):
	# 1. Validación de estado inválido o redundante
	if estado_actual == Estado.MUERTO or estado_actual == nuevo_estado:
		return
	
	# 2. Debug avanzado
	var prev_state = Estado.keys()[estado_actual]
	var new_state = Estado.keys()[nuevo_estado]
	print("Cambiando estado de %s a %s" % [prev_state, new_state])
	
	# 3. Lógica de salida del estado actual (segura)
	match estado_actual:
		Estado.ATAQUE:
			safe_stop("AttackCooldown")
			safe_stop("AttackAnimation")
		Estado.DANADO:
			modulate = Color.WHITE  # Restablecer color
	
	# 4. Lógica de entrada al nuevo estado (segura)
	match nuevo_estado:
		Estado.ALERTA:
			play_sound("alert")
		Estado.ATAQUE:
			start_attack_sequence()
		Estado.DANADO:
			start_damage_sequence()
		Estado.MUERTO:
			handle_death()
	
	# 5. Actualización final
	estado_actual = nuevo_estado

func safe_stop(node_path: String):
	if has_node(node_path) and get_node(node_path).has_method("stop"):
		get_node(node_path).stop()

func play_sound(sound_name: String):
	var audio_node = "Audio%s" % sound_name.capitalize()
	if has_node(audio_node):
		get_node(audio_node).play()

func start_attack_sequence():
	puede_cambiar_estado = false
	
	puede_cambiar_estado = true

func start_damage_sequence():
	if has_node("InvulnerabilityTimer"):
		$InvulnerabilityTimer.start(tiempo_invulnerabilidad)

func handle_death():
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	queue_free()
	
func update_animations(direction: Vector2):
	if updating_animations:
		return
	updating_animations = true
	
	if direction.length() > 0.1:
		last_direction = direction
	
	# Animaciones basadas en estado y dirección
	match estado_actual:
		Estado.IDLE:
			play_idle_animation()
		Estado.ALERTA:
			play_alert_animation()
		Estado.PERSEGUIR:
			play_walk_animation(direction)
		Estado.ATAQUE:
			animated_sprite.play("attack")
		Estado.DANADO:
			animated_sprite.play("damaged")
		Estado.MUERTO:
			animated_sprite.play("dead")
	updating_animations = false

func play_idle_animation():
	if abs(last_direction.x) > abs(last_direction.y):
		animated_sprite.play("right" if last_direction.x > 0 else "left")
	else:
		animated_sprite.play("down" if last_direction.y > 0 else "up")

func play_alert_animation():
	# Animación especial de alerta (parpadeo o efecto visual)
	#animated_sprite.play("alert")
	#await animated_sprite.animation_finished
	play_idle_animation()

func play_walk_animation(direction: Vector2):
	if not is_instance_valid(animated_sprite):
		return
	
	# Lógica de selección de animación SIN llamar a update_animations()
	var anim_name: String
	
	if abs(direction.x) > abs(direction.y):
		anim_name = "right" if direction.x > 0 else "left"
	else:
		anim_name = "down" if direction.y > 0 else "up"
	
	# Reproducir solo si es diferente a la actual
	if animated_sprite.animation != anim_name:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)









	
	# Calcula dirección manteniendo distancia mínima
	var to_player = player.global_position - global_position
	var desired_distance = 60.0  # Pixeles de separación mínima

	
	# Inicializa target_velocity correctamente
	var target_velocity: Vector2 = direction * speed
	
	if to_player.length() < desired_distance:
		# Si está demasiado cerca, alejarse ligeramente
		velocity = -direction * (speed * 0.3)
	else:
		# Movimiento normal de persecución
		velocity = velocity.lerp(target_velocity, acceleration)
	
	last_direction = direction
	
	# Manejo de colisiones mejorado
	move_and_slide()
	
	# Empuje al colisionar con el jugador
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player:
			var push_force = -collision.get_normal() * 45
			velocity += push_force
	
	update_animations(direction)
	
	
	#bandera de seguridad
func _draw():
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.2))  # Rojo
		draw_circle(Vector2.ZERO, attack_range * 0.8, Color(0, 1, 0, 0.2))  # Verde
