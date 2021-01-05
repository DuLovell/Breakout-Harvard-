--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.ball.dx = math.random(-200, 200)
    self.ball.dy = math.random(-50, -60)

    self.counter = params.counter or 0
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    self.ball:update(dt)

    if self.score - self.counter * 1000 >= 1000 then
        if self.paddle.size < 4 then
            self.paddle.size = self.paddle.size + 1
            self.paddle.width = self.paddle.width + 32
        end
        self.counter = self.counter + 1
    end

    if self.ball:collides(self.paddle)  then
        ballAndPaddle =  PlayState:paddleCollides(self.ball, self.paddle)
        self.ball = ballAndPaddle[1]
        self.paddle = ballAndPaddle[2]
    end

    if self.extraBalls then
        for k, ball in pairs(self.extraBalls) do
            if ball:collides(self.paddle) then
                ballAndPaddle =  PlayState:paddleCollides(ball, self.paddle)
                ball = ballAndPaddle[1]
                self.paddle = ballAndPaddle[2]
            end
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        -- only check collision if we're in play
        if brick.inPlay and self.ball:collides(brick) then
            playStateObjects = PlayState:bricksCollides(brick, self.ball, self)
            self.paddle = playStateObjects.paddle
            self.bricks = playStateObjects.bricks
            self.health = playStateObjects.health
            self.score = playStateObjects.score
            self.highScores = playStateObjects.highScores
            self.ball = playStateObjects.ball
            self.level = playStateObjects.level

            self.recoverPoints = playStateObjects.recoverPoints
            -- give ball random starting velocity
            self.ball.dx = playStateObjects.ball.dx
            self.ball.dy = playStateObjects.ball.dy
        end 

        if self.extraBalls then
            for k, ball in pairs(self.extraBalls) do
                if brick.inPlay and ball:collides(brick) then
                    playStateObjects = PlayState:bricksCollides(brick, ball, self)
                    self.paddle = playStateObjects.paddle
                    self.bricks = playStateObjects.bricks
                    self.health = playStateObjects.health
                    self.score = playStateObjects.score
                    self.highScores = playStateObjects.highScores
                    self.ball = playStateObjects.ball
                    self.level = playStateObjects.level

                    self.recoverPoints = playStateObjects.recoverPoints
                    -- give ball random starting velocity
                    self.ball.dx = playStateObjects.ball.dx
                    self.ball.dy = playStateObjects.ball.dy
                end
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    if self.ball.y >= VIRTUAL_HEIGHT then
        self.health = self.health - 1
        self.paddle.size = 1
        self.paddle.width = 32
        gSounds['hurt']:play()

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                counter = self.counter,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints
            })
        end
    end


    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)

        if brick.powerup and brick.powerup:collides(self.paddle) then

            if brick.powerup.type == 1 then
                self.extraBalls = PlayState:addBalls(self.ball)
            else
                self.blocks = PlayState:unlockBlock(self.bricks)
            end

            brick.powerup.remove = true
            table.remove(self.bricks, k)
        end


        if brick.powerup and brick.powerupSwitcher then
            brick.powerup:update(dt)
        end
    end

    if self.extraBalls then
        for k, ball in pairs(self.extraBalls) do
            ball:update(dt)
        end
    end
    


    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end


    self.paddle:render()
    self.ball:render()

    if self.extraBalls then
        for k, ball in pairs(self.extraBalls) do
            ball:render()
        end
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

----------------------------------------------------------------------------------------

function PlayState:addBalls(ball)
    local extraBalls = {
        Ball((ball.skin + 1) % 8),
        Ball((ball.skin + 1) % 8)
    }
    extraBalls[1].x, extraBalls[1].y = ball.x, ball.y
    extraBalls[1].dx, extraBalls[1].dy = ball.dx + math.random(-100, 100), ball.dy + math.random(-20, 20)

    extraBalls[2].x, extraBalls[2].y = ball.x, ball.y
    extraBalls[2].dx, extraBalls[2].dy = ball.dx + math.random(-100, 100), ball.dy + math.random(-20, 20)

    return extraBalls
end

function PlayState:unlockBlock(bricks)
    for k, brick in pairs(bricks) do
        if brick.blocked then
            brick.blocked = false
        end
    end

    return bricks
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

function PlayState:paddleCollides(ball, paddle)
    -- raise ball above paddle in case it goes below it, then reverse dy
    ball.y = paddle.y - 8
    ball.dy = -ball.dy

    --
    -- tweak angle of bounce based on where it hits the paddle
    --

    -- if we hit the paddle on its left side while moving left...
    if ball.x < paddle.x + (paddle.width / 2) and paddle.dx < 0 then
        ball.dx = -50 + -(8 * (paddle.x + paddle.width / 2 - ball.x))
    
    -- else if we hit the paddle on its right side while moving right...
    elseif ball.x > paddle.x + (paddle.width / 2) and paddle.dx > 0 then
        ball.dx = 50 + (8 * math.abs(paddle.x + paddle.width / 2 - ball.x))
    end

    gSounds['paddle-hit']:play()
    
    return {ball, paddle}
end


function PlayState:bricksCollides(brick, ball, playStateObjects)
    -- add to score
    if not brick.blocked then
        playStateObjects.score = playStateObjects.score + (brick.tier * 200 + brick.color * 25)
    end

    -- trigger the brick's hit function, which removes it from play
    brick:hit()

    -- if we have enough points, recover a point of health
    if playStateObjects.score > playStateObjects.recoverPoints then
        -- can't go above 3 health
        playStateObjects.health = math.min(3, playStateObjects.health + 1)

        -- multiply recover points by 2
        playStateObjects.recoverPoints = playStateObjects.recoverPoints + math.min(100000, playStateObjects.recoverPoints * 2)

        -- play recover sound effect
        gSounds['recover']:play()
    end

    -- go to our victory screen if there are no more bricks left
    if playStateObjects:checkVictory() then
        gSounds['victory']:play()

        gStateMachine:change('victory', {
            level = playStateObjects.level,
            paddle = playStateObjects.paddle,
            health = playStateObjects.health,
            score = playStateObjects.score,
            highScores = playStateObjects.highScores,
            ball = ball,
            recoverPoints = playStateObjects.recoverPoints
        })
    end

    --
    -- collision code for bricks
    --
    -- we check to see if the opposite side of our velocity is outside of the brick;
    -- if it is, we trigger a collision on that side. else we're within the X + width of
    -- the brick and should check to see if the top or bottom edge is outside of the brick,
    -- colliding on the top or bottom accordingly 
    --

    -- left edge; only check if we're moving right, and offset the check by a couple of pixels
    -- so that flush corner hits register as Y flips, not X flips
    if ball.x + 2 < brick.x and ball.dx > 0 then
        
        -- flip x velocity and reset position outside of brick
        ball.dx = -ball.dx
        ball.x = brick.x - 8
    
    -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
    -- so that flush corner hits register as Y flips, not X flips
    elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
        
        -- flip x velocity and reset position outside of brick
        ball.dx = -ball.dx
        ball.x = brick.x + 32
    
    -- top edge if no X collisions, always check
    elseif ball.y < brick.y then
        
        -- flip y velocity and reset position outside of brick
        ball.dy = -ball.dy
        ball.y = brick.y - 8
    
    -- bottom edge if no X collisions or top collision, last possibility
    else
        
        -- flip y velocity and reset position outside of brick
        ball.dy = -ball.dy
        ball.y = brick.y + 16
    end

    -- slightly scale the y velocity to speed up the game, capping at +- 150
    if math.abs(ball.dy) < 150 then
        ball.dy = ball.dy * 1.02
    end

    -- only allow colliding with one brick, for corners
    return playStateObjects
end