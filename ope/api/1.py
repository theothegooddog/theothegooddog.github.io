# Default Game for OpenPhysicsEngine (9/8/26)
# This line above ^ will be the scene name for errors and stuff.
# Lines after are comments
# We have the basic dependencies for the game along with time, random, and math

floor = Object.create("Floor")
point = Object.create("Point")
point.setProperty(Property.Restitution, 0.7)
point.setProperty(Property.Position, (-50, 50, 0))
point.setProperty(Property.Velocity, (2, 0, 0))
point.setProperty(Property.Friction, 2)
floor.setProperty(Property.Position, (0, -20, 0))
workspace.addObject(point)
workspace.addObject(floor)
workspace.setProperty(Property.AirResistance, 1)
code = Object.create("Code")
code.Source = """
randp = Object.create("Point")
randp.Name = "random part"
workspace.addObject(randp)
while True:
	randp.setProperty(Property.Position,[random.randint(-5,5),random.randint(-5,5),random.randint(-5,5)])
	time.sleep(1)
"""
for d in range(0,int(math.pi*200)):
	d/=100
	circle = Object.create("Point")
	circle.Position = [math.sin(d),10,math.cos(d)]
	circle.Size = [1,1,1]