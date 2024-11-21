def draw_cube(size):
    # Draw the top of the cube
    print(" " * (size // 2) + "+" + "-" * size + "+")
    for i in range(size // 2):
        print(" " * ((size // 2) - i - 1) + "/" + " " * size + "/" + "|")

    # Draw the front and side of the cube
    for i in range(size):
        if i < size - 1:
            print("+" + "-" * size + "+" + " " * (size // 2 - i) + "|")
        else:
            print("+" + "-" * size + "+")
        
        for j in range(size // 2):
            if i < size - 1:
                print("|" + " " * size + "|" + " " * (size // 2 - j - 1) + "+")
            else:
                print("|" + " " * size + "|" + " " * (size // 2 - j - 1) + "/")

    # Draw the bottom of the cube
    for i in range(size // 2):
        print(" " * i + "+" + "-" * size + "+")
    
# Call the function to draw a cube of a specified size
draw_cube(6)
