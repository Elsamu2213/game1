extends CharacterBody2D

@export var speed := 300.0
@export var acceleration := 0.2
@export var friction := 0.15

func _physics_process(delta):
	# 1. Obtener input WASD
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. Calcular velocidad objetivo
	var target_velocity := direction * speed
	
	# 3. Interpolar suavemente
	velocity = velocity.lerp(target_velocity, acceleration if direction else friction)
	
	# 4. Mover y deslizar
	move_and_slide()
	
	# Debug: Imprime la velocidad actual
	print("Velocity: ", velocity)
