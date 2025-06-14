extends CharacterBody2D


@export var speed := 300.0
@export var acceleration := 0.2
@export var friction := 0.15

@onready var animated_sprite := $AnimatedSprite2D  # Asegúrate de que la ruta coincida con tu estructura de nodos
var last_direction := Vector2.DOWN# Dirección inicial por defecto (abajo)

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
