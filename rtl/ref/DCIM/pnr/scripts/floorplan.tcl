puts "--- Floorplan ---"

# Core Height / Width 长宽比
set AspectRatio 1.0
# Core 利用率
set CoreDensity 0.7
# Core到Die边缘的距离(um)
set CoreMargin 10.0 
# Macro到Core边缘的距离(um)
set MacroMargin 10.0
# Macro附近留给引脚的区域
set MacroHalo 2.0
# Macro无引脚侧的安全间距
set MacroMinHalo 0.1
# Macro布线阻塞边缘宽度
set MacroRBSpace 0.5

puts "--> 1. Creating Floorplan..."
floorplan -r ${AspectRatio} ${CoreDensity} ${CoreMargin} ${CoreMargin} ${CoreMargin} ${CoreMargin}

puts "--> 3. Adding Halos & Blocks for Sram..."
# Left-Bottom-Right-Top
addHaloToBlock ${MacroMinHalo} ${MacroMinHalo} ${MacroHalo} ${MacroHalo} -allMacro
createRouteBlk -cover -inst ${MacroInstance} -layer {M1 M2 M3 M4} -exceptpgnet -spacing ${MacroRBSpace}

puts "--> 4. Placing Pins..."
editPin -side Left -layer 5 -spreadType start 1.2 -offsetStart 30 \
	-pin {clk rstn ena {up_data_memory[*]}}

