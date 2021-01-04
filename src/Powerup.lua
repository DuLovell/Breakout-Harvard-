Powerup = Class{}

function Powerup:init(brick)
    self.type = math.random(1, 2)  -- 1 == 'balls'; 2 == 'key'
    
    self.width = 16
    self.height = 16

    self.x = brick.x + brick.width / 2 - self.width / 2
    self.y = brick.y + brick.height / 2 - self.height / 2

    self.dy = POWERUP_SPEED

    self.remove = false
end


function Powerup:update(dt)
    self.y = self.y + self.dy
end


function Powerup:render()
    if not self.remove then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type], self.x, self.y)
    end
end

--------------------------------------------------------------------------
function Powerup:collides(target)
    if self.y + self.height < target.y or self.y > target.y + target.height then
        return false
    end

    if self.x + self.width < target.x or self.x > target.x + target.width then
        return false
    end

    return true
end

function Powerup:addBalls()

end

function Powerup:grabKey()

end