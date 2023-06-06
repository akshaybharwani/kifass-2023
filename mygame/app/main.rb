# samples/docs referred
# ./samples/02_input_basics/01_moving_a_sprite: movement spaceship
# ./samples/05_mouse/02_mouse_move:             rotating spaceship, enemy spawning

# Helpful thing to erase the screen, might wanna take it out when publishing
$gtk.reset

# This is the only function that DragonRuby cares about. And it runs 60 times a second
# So that we don't have to worry about Delta time and stuff
def tick(args)
  # Only need to do this once, creating a new object
  args.state.game ||= TetrisGame.new(args)
  args.state.game.tick(args)
end

class TetrisGame
  def initialize(args)
    @args = args

    # game
    @score = 0
    @game_over = false

    # spaceship
    @spaceship_speed ||= 5
    args.state.spaceship.x ||= 0
    args.state.spaceship.y ||= 0
    args.state.spaceship.w ||= 45
    args.state.spaceship.h ||= 45

    # enemies
    @enemy_speed                      ||= 0.5
    args.state.enemy_min_spawn_rate   ||= 60
    args.state.enemy_spawn_countdown  ||= random_spawn_countdown(args.state.enemy_min_spawn_rate)
    args.state.enemies                ||= []
    args.state.spaceship_moving       ||= false

    # shooting lines
    args.state.shooting_lines               ||= []
    args.state.current_shooting_origin      ||= nil
    args.state.last_destination_enemy_index ||= 0
    args.state.closest_enemy_index          ||= 0

    # actual shooting
    args.state.animation_type     ||= [:quad]
    args.state.animation_duration ||= 1.seconds
    args.state.startup_time       ||= 1.seconds
    args.state.animation_progress ||= 0
    args.state.shooting           ||= false
  end

  # Your own Tick function, can do everything here
  def tick(args)
    input
    #iterate
    calc
    render
  end

  def input
    @args.state.spaceship_moving = false
    # we should always check the input first, before other logic
    # so that players don't get a 60ms lag
    # this is a local variable
    inputs = @args.inputs
    keyboard = @args.inputs.keyboard
    controller = @args.inputs.controller_one
    # check for game restart
    if @game_over && (keyboard.key_down.space || controller.key_down.start)
      $gtk.reset
    end

    player_movement(inputs)
    

    # create a point based off of the mouse location
    @args.state.mouse_location = {
      x: inputs.mouse.x,
      y: inputs.mouse.y
    }

    # controlling shooting lines
    if !@args.state.spaceship_moving
      if keyboard.key_up.space
        @args.state.shooting = true
      end
      if @args.state.shooting
        shoot
      end

      if inputs.mouse.button_left && inputs.mouse.click  # save the line on mouse left button click
        if !does_shooting_line_already_exist?(@args.state.closest_enemy_index)
          shooting_line = {
            origin_index: @args.state.last_destination_enemy_index,
            destination_index: @args.state.closest_enemy_index
          }
          @args.state.shooting_lines.push(shooting_line)
          @args.state.last_destination_enemy_index = @args.state.closest_enemy_index
        end
      elsif inputs.mouse.button_right && inputs.mouse.click # delete the last line on mouse right button click
        @args.state.shooting_lines.pop
      elsif inputs.mouse.button_middle && inputs.mouse.click # delete all the lines on mouse middle button click
        @args.state.shooting_lines.clear
      end
    end

    #@args.outputs.debug << { x: 640, y: 25, text: @args.state.spaceship.angle, size_enum: -2, alignment_enum: 1, r: 255, g: 255, b: 255 }.label!
  end

  def player_movement(inputs)
    return if @args.state.shooting
    # movement
    if inputs.up
      @args.state.spaceship_moving = true
      @args.state.spaceship.y += @spaceship_speed
    elsif inputs.down
      @args.state.spaceship_moving = true
      @args.state.spaceship.y -= @spaceship_speed
    end

    if inputs.left
      @args.state.spaceship_moving = true
      @args.state.spaceship.x -= @spaceship_speed
    elsif inputs.right
      @args.state.spaceship_moving = true
      @args.state.spaceship.x += @spaceship_speed
    end

    # rotation
    if inputs.mouse.moved
      @args.state.spaceship.angle = (inputs.mouse.position.angle_from [@args.state.spaceship.x, @args.state.spaceship.y])
      # TODO: This sets the proper angle, figure out why
      @args.state.spaceship.angle -= 90
    end
  end

  def shoot
    if !@args.state.shooting_lines.empty?
      @args.state.shooting_lines.each_with_index do |current_line, index|
        origin_enemy = @args.state.enemies[current_line[:origin_index]]
        destination_enemy = @args.state.enemies[current_line[:destination_index]]
        progress = (index * @args.state.animation_duration + @args.state.startup_time).ease(@args.state.animation_duration, @args.state.animation_type)
          
        calc_x = origin_enemy.x + (destination_enemy.x - origin_enemy.x) * progress
        calc_y = origin_enemy.y + (destination_enemy.y - origin_enemy.y) * progress

        @args.state.spaceship.x = calc_x
        @args.state.spaceship.y = calc_y
      end
      @args.state.shooting = false
      @args.state.shooting_lines.clear
    end
  end

  def iterate
    if @game_over
      return
    end
  end

  # Calls all methods necessary for performing calculations.
  def calc
    calc_spawn_enemy
    calc_move_enemies
    calc_shooting_line
    #calc_player
    #calc_kill_enemy
  end

  # Decreases the enemy spawn countdown by 1 if it has a value greater than 0.
  def calc_spawn_enemy
    return if @args.state.spaceship_moving == false

    if @args.state.enemy_spawn_countdown > 0
      @args.state.enemy_spawn_countdown -= 1
      return
    end

    # New enemies are created, positioned on the screen, and added to the enemies collection.
    @args.state.enemies << @args.state.new_entity(:enemy) do |z| # each enemy is declared a new entity
      if rand > 0.5
        z.x = @args.grid.rect.w.randomize(:ratio) # random x position on screen (within grid scope)
        z.y = [-10, 730].sample # y position is set to either -10 or 730 (randomly chosen)
        # the possible values exceed the screen's scope so enemies appear to be coming from far away
      else
        z.x = [-10, 1290].sample # x position is set to either -10 or 1290 (randomly chosen)
        z.y = @args.grid.rect.w.randomize(:ratio) # random y position on screen
      end
    end

    # Calls random_spawn_countdown method (determines how fast new enemies appear)
    @args.state.enemy_spawn_countdown = random_spawn_countdown(@args.state.enemy_min_spawn_rate)
    @args.state.enemy_min_spawn_rate -= 1
    # set to either the current enemy_min_spawn_rate or 0, depending on which value is greater
    @args.state.enemy_min_spawn_rate  = @args.state.enemy_min_spawn_rate.greater(0)
  end

  # Moves all enemies towards the center of the screen.
  # All enemies that reach the center (640, 360) are rejected from the enemies collection and disappear.
  def calc_move_enemies
    return if @args.state.spaceship_moving == false
    @args.state.enemies.each do |z| # for each enemy in the collection
      z.y = z.y.towards(@args.state.planet_y_pos, @enemy_speed) # move the enemy towards the center (640, 360) at a rate of 0.1
      z.x = z.x.towards(@args.state.planet_x_pos, @enemy_speed) # change 0.1 to 1.1 and see how much faster the enemies move to the center
    end
    @args.state.enemies = @args.state.enemies.reject { |z| z.y == @args.state.planet_y_pos && z.x == @args.state.planet_x_pos } # remove enemies that are in center
  end

  def calc_shooting_line
    return if @args.state.spaceship_moving

    find_closest_enemy

    @args.state.spaceship_shooting_position = {
      x: @args.state.spaceship.x + @args.state.spaceship.w / 2,
      y: @args.state.spaceship.y + @args.state.spaceship.h / 2
    }

    # then check saved lines
    if !@args.state.shooting_lines.empty?
      @args.state.shooting_lines.each_with_index do |current_line, index|
        origin_enemy = @args.state.enemies[current_line[:origin_index]]
        destination_enemy = @args.state.enemies[current_line[:destination_index]]
        if index == 0
          render_shooting_line(@args.state.spaceship_shooting_position, destination_enemy)
        else 
          render_shooting_line(origin_enemy, destination_enemy)
        end
        if index == @args.state.shooting_lines.size - 1
          @args.state.current_shooting_position = [destination_enemy.x, destination_enemy.y]
        end
      end
    else 
      @args.state.current_shooting_position = @args.state.spaceship_shooting_position
    end
    closest_enemy = @args.state.enemies[@args.state.closest_enemy_index]
    if closest_enemy && !does_shooting_line_already_exist?(@args.state.closest_enemy_index)
      render_shooting_line(@args.state.current_shooting_position, closest_enemy)
    end
    # perform ray_test on point and line
    #ray = @args.geometry.ray_test @args.state.mouse_location, @args.state.shooting_line
  end

  def find_closest_enemy
    # find closest enemy
    shortest_distance = nil
    closest_enemy_index = nil

    @args.state.enemies.each_with_index do |enemy, index|
      # Calculate the distance between enemy and mouse position using args.geometry.distance
      distance = @args.geometry.distance(
        [enemy.x, enemy.y],
        [@args.state.mouse_location.x, @args.state.mouse_location.y]
      )

      # Check if the current enemy is the closest one
      if shortest_distance.nil? || distance < shortest_distance
        shortest_distance = distance
        if closest_enemy_index != index && !does_shooting_line_already_exist?(index)
          closest_enemy_index = index
        end
      end
    end

    if closest_enemy_index
      @args.state.closest_enemy_index = closest_enemy_index
      closest_enemy = @args.state.enemies[@args.state.closest_enemy_index]
      @args.outputs.borders << {x: closest_enemy.x, y: closest_enemy.y, w: 30, h: 30, r: 255, g: 255, b: 255}
    end
  end

  def does_shooting_line_already_exist?(target_index)
    @args.state.shooting_lines.any? { |line| line[:origin_index] == target_index }
  end

  def render
    render_background
    render_sun
    render_planet
    render_spaceship
    render_enemies
  end

  def render_background
    @args.outputs.solids << [0, 0, 1280, 720, 0, 0, 0]
  end

  def render_sun
    sun_width = 150
    sun_height = 150
    sun_x_pos = (1280 / 2) - (sun_width / 2)
    sun_y_pos = (720 / 2) - (sun_height / 2)
    @args.outputs.sprites << [sun_x_pos, sun_y_pos, sun_width, sun_height, 'sprites/sphere0.png', 0, 255, 255, 165, 0]
  end

  def render_planet
    @args.state.rotate_amount ||= 0
    if @args.state.spaceship_moving
      @args.state.rotate_amount  += 0.5

      if @args.state.rotate_amount >= 360
        @args.state.rotate_amount = 0
      end
    end

    planet_starting_position ||= {
      x: 640 + 150,
      y: 360 + 150
    }

    # rotate point around center screen
    rotate_point = @args.geometry.rotate_point planet_starting_position,
                                                 @args.state.rotate_amount,
                                                 x: 640, y: 360

    planet_width = 100
    planet_height = 100
    @args.state.planet_x_pos = rotate_point.x - (planet_width / 2)
    @args.state.planet_y_pos = rotate_point.y - (planet_height / 2)
    @args.outputs.sprites << [@args.state.planet_x_pos, @args.state.planet_y_pos, planet_width, planet_height, 'sprites/planet03.png']
  end

  def render_spaceship
    @args.state.spaceship.w ||= 45
    @args.state.spaceship.h ||= 45
    @args.state.spaceship.x ||= 900 - (@args.state.spaceship.w / 2)
    @args.state.spaceship.y ||= 200 - (@args.state.spaceship.h / 2)
    @args.state.spaceship.angle ||= 0

    @args.outputs.sprites << { x: @args.state.spaceship.x,
                              y: @args.state.spaceship.y,
                              w: @args.state.spaceship.w,
                              h: @args.state.spaceship.h,
                              path: 'sprites/ship_A.png',
                              angle: @args.state.spaceship.angle }
  end

# Outputs the enemies on the screen and sets values for the sprites, such as the position, width, height, and animation.
  def render_enemies
    @args.outputs.sprites << @args.state.enemies.map do |z| # performs action on all zombies in the collection
      angle = ([@args.state.planet_x_pos, @args.state.planet_y_pos].angle_from [z.x, z.y])
      angle -= 90
      z.sprite = [z.x, z.y, 30, 30, 'sprites/enemy_A.png', angle].sprite # sets definition for sprite, calls animation_sprite method
      z.sprite
    end
  end

  # Sets the enemy spawn's countdown to a random number.
  # How fast enemies appear (change the 60 to 6 and too many enemies will appear at once!)
  def random_spawn_countdown(minimum)
    10.randomize(:ratio, :sign).to_i + minimum
  end

  def render_shooting_line(origin, destination) 
    return if @args.state.spaceship_moving
    shooting_line = {

      x:  origin.x,
      y:  origin.y,
      x2: destination.x,
      y2: destination.y,
      r:  255,
      g:  255,
      b:  255
    }
    # render line
    @args.outputs.lines << shooting_line
  end
end