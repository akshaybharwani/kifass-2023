# samples/docs referred
# ./samples/02_input_basics/01_moving_a_sprite: movement spaceship
# ./samples/05_mouse/02_mouse_move:             rotating spaceship, enemy spawning

# Helpful thing to erase the screen, might wanna take it out when publishing
$gtk.reset

# This is the only function that DragonRuby cares about. And it runs 60 times a second
# So that we don't have to worry about Delta time and stuff
def tick(args)
  # Only need to do this once, creating a new object
  args.state.game ||= Game.new(args)
  args.state.game.tick(args)
end

class Game
  def initialize(args)
    @args = args

    # game
    @game_screen_width       ||= 1280
    @game_screen_height      ||= 720
    args.state.score         ||= 0
    args.state.game_over     ||= false
    args.state.boings_limit  ||= 10
    args.state.current_level ||= 0

    # planet
    @planet_speed ||= 0.3

    # spaceship
    args.state.spaceship ||= args.state.new_entity(:spaceship) do |spaceship|
      spaceship.speed = 4
      spaceship.w     = 45
      spaceship.h     = 45
      spaceship.x     = 900 - (spaceship.w / 2)
      spaceship.y     = 200 - (spaceship.h / 2)
      spaceship.angle = 0
    end

    # enemies
    @enemy_speed                     ||= 0.5
    args.state.enemy_min_spawn_rate  ||= 50
    args.state.enemy_spawn_countdown ||= random_spawn_countdown(args.state.enemy_min_spawn_rate)
    args.state.enemies               ||= []
    args.state.spaceship_moving      ||= false

    # shooting lines
    args.state.shooting_lines                ||= []
    args.state.current_shooting_origin       ||= nil
    args.state.last_destination_enemy_entity ||= nil
    args.state.closest_enemy_entity          ||= nil

    # actual shooting
    @shooting_speed     ||= 30
    args.state.shooting ||= false
  end

  # Your own Tick function, can do everything here
  def tick(args)
    input
    # iterate
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
      if keyboard.key_up.space && !@args.state.shooting
        @args.state.shooting = true
      end
      if @args.state.shooting
        shoot
      end

      if inputs.mouse.button_left && inputs.mouse.click # save the line on mouse left button click
        if @args.state.shooting_lines.empty?
          add_shooting_line(@args.state.spaceship, @args.state.closest_enemy_entity)
        else
          add_shooting_line(@args.state.last_destination_enemy_entity, @args.state.closest_enemy_entity)
        end
      elsif inputs.mouse.button_right && inputs.mouse.click # delete the last line on mouse right button click
        @args.state.shooting_lines.pop
      elsif inputs.mouse.button_middle && inputs.mouse.click # delete all the lines on mouse middle button click
        @args.state.shooting_lines.clear
      end
    end

    # @args.outputs.debug << { x: 640, y: 25, text: @args.state.spaceship.angle, size_enum: -2, alignment_enum: 1, r: 255, g: 255, b: 255 }.label!
  end

  def add_shooting_line(origin_entity, destination_entity)
    return if does_shooting_line_already_exist?(destination_entity)
    return unless can_shoot?

    shooting_line = {
      origin_entity: origin_entity,
      destination_entity: destination_entity
    }

    @args.state.shooting_lines.push(shooting_line)
    @args.state.last_destination_enemy_entity = destination_entity
  end

  def player_movement(inputs)
    return if @args.state.shooting

    # movement
    if inputs.up
      @args.state.spaceship_moving = true
      @args.state.spaceship.y += @args.state.spaceship.speed
    elsif inputs.down
      @args.state.spaceship_moving = true
      @args.state.spaceship.y -= @args.state.spaceship.speed
    end

    if inputs.left
      @args.state.spaceship_moving = true
      @args.state.spaceship.x -= @args.state.spaceship.speed
    elsif inputs.right
      @args.state.spaceship_moving = true
      @args.state.spaceship.x += @args.state.spaceship.speed
    end

    # rotation
    if inputs.mouse.moved
      @args.state.spaceship.angle = (inputs.mouse.position.angle_from [@args.state.spaceship.x,
                                                                       @args.state.spaceship.y])
      # TODO: This sets the proper angle, figure out why
      @args.state.spaceship.angle -= 90
    end
  end

  def shoot
    if !@args.state.shooting_lines.empty?
      @args.state.current_shooting_destination_entity ||= @args.state.shooting_lines[0][:destination_entity]

      destination_entity = @args.state.current_shooting_destination_entity
      spaceship          = @args.state.spaceship

      tolerance = @shooting_speed / 2

      if (spaceship.x - destination_entity.x).abs < tolerance && (spaceship.y - destination_entity.y).abs < tolerance
        if @args.state.shooting_lines.size > 0
          set_next_shooting_destination_entity
        end
      else
        move_towards_destination_entity(spaceship, destination_entity)
      end
    else
      finish_shooting
    end
  end

  def finish_shooting
    @args.state.shooting = false
  end

  def set_next_shooting_destination_entity
    destroy_enemy(@args.state.current_shooting_destination_entity)

    @args.state.shooting_lines.delete_at(0)
    @args.state.current_shooting_destination_entity = @args.state.shooting_lines[0][:destination_entity]
  end

  def destroy_enemy(enemy)
    @args.state.enemies.delete(enemy)
  end

  def move_towards_destination_entity(spaceship, destination_entity)
    angle      = Math.atan2(destination_entity.y - spaceship.y, destination_entity.x - spaceship.x)
    velocity_x = Math.cos(angle) * @shooting_speed
    velocity_y = Math.sin(angle) * @shooting_speed

    spaceship.x += velocity_x
    spaceship.y += velocity_y
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
    # calc_player
    # calc_kill_enemy
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
      z.w = 30
      z.h = 30
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
    return if !@args.state.spaceship_moving

    @args.state.enemies.each do |z| # for each enemy in the collection
      z.y = z.y.towards(@args.state.planet_y_pos, @enemy_speed) # move the enemy towards the center (640, 360) at a rate of 0.1
      z.x = z.x.towards(@args.state.planet_x_pos, @enemy_speed) # change 0.1 to 1.1 and see how much faster the enemies move to the center
    end
    @args.state.enemies = @args.state.enemies.reject { |z|
      z.y == @args.state.planet_y_pos && z.x == @args.state.planet_x_pos
    } # remove enemies that are in center
  end

  def calc_shooting_line
    return if @args.state.spaceship_moving

    find_closest_enemy_entity

    if !@args.state.shooting_lines.empty?
      render_all_shooting_lines
    else
      @args.state.current_shooting_entity = @args.state.spaceship
    end

    closest_enemy = @args.state.closest_enemy_entity

    if closest_enemy && !does_shooting_line_already_exist?(closest_enemy) && can_shoot?
      render_shooting_line(@args.state.current_shooting_entity, closest_enemy)
    end
  end

  def find_closest_enemy_entity
    shortest_distance = nil
    closest_enemy_entity = nil

    @args.state.enemies.each_with_index do |enemy|
      # Calculate the distance between enemy and mouse position using args.geometry.distance
      distance = @args.geometry.distance(
        [enemy.x, enemy.y],
        [@args.state.mouse_location.x, @args.state.mouse_location.y]
      )

      # Check if the current enemy is the closest one
      if shortest_distance.nil? || distance < shortest_distance
        shortest_distance = distance
        if closest_enemy_entity != enemy && !does_shooting_line_already_exist?(enemy)
          closest_enemy_entity = enemy
        end
      end
    end

    if closest_enemy_entity && can_shoot?
      @args.state.closest_enemy_entity = closest_enemy_entity
      @args.outputs.borders << { x: closest_enemy_entity.x, y: closest_enemy_entity.y, w: closest_enemy_entity.w,
                                 h: closest_enemy_entity.h, r: 255, g: 255, b: 255 }
    end
  end

  def render_all_shooting_lines
    @args.state.shooting_lines.each_with_index do |current_line, index|
      origin_entity = current_line[:origin_entity]
      destination_entity = current_line[:destination_entity]

      render_shooting_line(origin_entity, destination_entity)

      if index == @args.state.shooting_lines.size - 1
        @args.state.current_shooting_entity = destination_entity
      end
    end
  end

  def does_shooting_line_already_exist?(target_entity)
    @args.state.shooting_lines.any? { |line| line[:destination_entity] == target_entity }
  end

  def can_shoot?
    @args.state.shooting_lines.size < @args.state.boings_limit
  end

  def render
    render_background
    render_sun
    render_planet
    render_spaceship
    render_enemies
    render_ui
  end

  def render_background
    @args.outputs.solids << [0, 0, @game_screen_width, @game_screen_height, 0, 0, 0]
=begin
    start_looping_at = 0
    number_of_sprites = 9
    number_of_frames_to_show_each_sprite = 4
    does_sprite_loop = true

    sprite_index =
      start_looping_at.frame_index(number_of_sprites,
                                   number_of_frames_to_show_each_sprite,
                                   does_sprite_loop)

    sprite_index ||= 0

    @args.outputs.sprites << [
      0, 0, @game_screen_width, @game_screen_height,
      "sprites/background/Starry background#{sprite_index}.png"
    ]
=end
  end

  def render_sun
    sun_width = 150
    sun_height = 150
    sun_x_pos = (@game_screen_width / 2) - (sun_width / 2)
    sun_y_pos = (@game_screen_height / 2) - (sun_height / 2)
    @args.outputs.sprites << [sun_x_pos, sun_y_pos, sun_width, sun_height, 'sprites/sphere0.png', 0, 255, 255, 165, 0]
  end

  def render_planet
    @args.state.rotate_amount ||= 0
    if @args.state.spaceship_moving
      @args.state.rotate_amount += 1 * @planet_speed

      if @args.state.rotate_amount >= 360
        @args.state.rotate_amount = 0
      end
    end

    planet_starting_position ||= {
      x: @game_screen_width / 2 + 150,
      y: @game_screen_height / 2 + 150
    }

    # rotate point around center screen
    rotate_point = @args.geometry.rotate_point planet_starting_position,
                                               @args.state.rotate_amount,
                                               x: @game_screen_width / 2, y: @game_screen_height / 2

    planet_width = 100
    planet_height = 100
    @args.state.planet_x_pos = rotate_point.x - (planet_width / 2)
    @args.state.planet_y_pos = rotate_point.y - (planet_height / 2)
    @args.outputs.sprites << [@args.state.planet_x_pos, @args.state.planet_y_pos, planet_width, planet_height,
                              'sprites/planet03.png']
  end

  def render_spaceship
    @args.outputs.sprites << { x: @args.state.spaceship.x,
                               y: @args.state.spaceship.y,
                               w: @args.state.spaceship.w,
                               h: @args.state.spaceship.h,
                               path: 'sprites/Main Ship - Base - Full health.png',
                               angle: @args.state.spaceship.angle }
  end

  # Outputs the enemies on the screen and sets values for the sprites, such as the position, width, height, and animation.
  def render_enemies
    @args.outputs.sprites << @args.state.enemies.map do |z| # performs action on all zombies in the collection
      angle = ([@args.state.planet_x_pos, @args.state.planet_y_pos].angle_from [z.x, z.y])
      angle -= 90
      z.sprite = [z.x, z.y, z.w, z.h, 'sprites/Klaed - Battlecruiser - Base.png', angle].sprite # sets definition for sprite, calls animation_sprite method
      z.sprite
    end
  end

  def render_ui
    render_level_ui
    # render_boings
  end

  def render_level_ui
    render_level_bar
  end

  def render_level_bar
    margin = 80
    height = 40
    level_bar = {
      x: margin,
      y: @game_screen_height - height * 2
    }

    @args.outputs.primitives << [level_bar.x, level_bar.y, get_current_level_progress(margin), height, 255,
                                 255, 255].solid
    @args.outputs.borders << { x: level_bar.x, y: level_bar.y, w: @game_screen_width - (margin * 2), h: height, r: 255,
                               g: 255, b: 255 }
  end

  def get_current_level_progress(margin)
    (@args.state.rotate_amount.to_i / 360) * (@game_screen_width - (margin * 2))
  end

  def render_boings
    boings_margin = 40
    @args.outputs.labels << [@game_screen_width - boings_margin, @game_screen_height - boings_margin,
                             "#{@args.state.boings_limit}", 255, 255, 255]
  end

  # Sets the enemy spawn's countdown to a random number.
  # How fast enemies appear (change the 60 to 6 and too many enemies will appear at once!)
  def random_spawn_countdown(minimum)
    10.randomize(:ratio, :sign).to_i + minimum
  end

  def render_shooting_line(origin, destination)
    return if @args.state.spaceship_moving

    shooting_line = {

      x: origin.x + origin.w / 2,
      y: origin.y + origin.h / 2,
      x2: destination.x + destination.w / 2,
      y2: destination.y + destination.h / 2,
      r: 255,
      g: 255,
      b: 255

    }
    # render line
    @args.outputs.lines << shooting_line
  end
end
