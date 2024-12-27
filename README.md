# Convolutional Neural Network for Real-Time Digit Detector in FPGA

- **Key Challenges:**
  - Adapting CNNs for FPGAs. 
  - Meeting real-time processing demands with limited hardware resources.
  - Addressing inefficiencies through image resizing and low-bit data representations.

- **Performance Improvements:**
  - Minimizing network size. 
  - Implement hardware-based convolution operations for faster processing. 
  - Replace floating-point arithmetic with fixed-point computation to reduce overhead.



## Software Tools

Python 3.5, Tensorflow 1.4.0, Keras 2.1.3



## Neural Network Structure

![Neural Net Structure](images/Neural-Net-Structure.png)



## Devices
To recreate the device you need 3 components:
* [DE2-115 FPGA](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502) (\$423 Academic or \$779 Personal)
* [OV7670 Camera Module](https://hshop.vn/mach-camera-ov7670) (43.000₫)
* [2.8 TFT SPI 240x320 V1.2](https://cdn-shop.adafruit.com/datasheets/ILI9341.pdf) (~500.000₫)



## Simulation of TOP.v

![Waveform1](images/Waveform1.png)

![Waveform2](images/Waveform2.png)

![Waveform3](images/Waveform3.png)

**Finite State Machine (FSM)** is designed for a **Convolutional Neural Network (CNN)** implemented in **Verilog**. The FSM controls different **processing levels** and **operations** such as **convolution**, **max-pooling**, and **dense layer computations**.

### 1. Purpose:

The FSM coordinates **CNN operations** step-by-step, including:

1. **Convolutional Layers (conv)** – Feature extraction using convolutional filters.
2. **Max-Pooling Layers (maxp)** – Down-sampling to reduce spatial dimensions.
3. **Dense Layers (dense)** – Fully connected layers for final classification.
4. **Result Computation (result)** – Produces the final classification output.

### 2. Key Registers and Variables:

1. **Control Signals:**
   - `GO` – Start signal for computation.
   - `STOP` – Stops the FSM after completing all operations.
   - `nextstep` – Indicates readiness to proceed to the next step.
2. **Level and Step Management:**
   - `TOPlvl` – Tracks the current layer of computation.
   - `lvl` and `slvl` – Fine-grained levels within each top-level layer.
   - `step` – Represents the current processing stage within each layer.
3. **Memory Management:**
   - `memstartp` and `memstartzap` – Memory pointers for input and output data.
   - `matrix` and `matrix2` – Define the dimensions of the data being processed.
4. **Enable Signals:**
   - `conv_en` – Enables convolution computation.
   - `maxp_en` – Enables max-pooling computation.
   - `dense_en` – Enables dense layer computation.
   - `result_en` – Enables result computation.

### 3. FSM Operations:

#### 3.1. Initialization (Triggered by GO Signal):

```verilog
if (GO==1)
```

- Resets the FSM.
- Sets memory locations, disables pooling (`globmaxp_en`), and disables dense layers (`dense_en`).
- Prepares the system for the first computation.

#### 3.2. Convolution Layers (TOPlvl = 1, 2, 4, 5, 8, 9):

**Convolution Enable:**

```verilog
conv_en = 1;
```

- Performs convolution operations at various levels.
- Uses `memstartp` and `memstartzap` for memory management.
- Matrix size (`matrix`) changes based on layer (28 → 14 → 7).

#### 3.3. Max-Pooling Layers (TOPlvl = 3, 6, 7):

**Max-Pooling Enable:**

```verilog
maxp_en = 1;
```

- Reduces spatial dimensions by pooling features.
- Uses offsets based on `num_conv`.
- Dynamically adjusts memory positions for input and output based on pooling size.

#### 3.4. Dense Layers (TOPlvl = 10):

**Dense Enable:**

```verilog
dense_en = 1;
```

- Activates dense layers for fully connected neural network processing.
- Configures input (`in_dense`) and output (`out_dense`) neuron counts.
- Includes optional dropout for zeroing out weights (`nozero_dense`).

#### 3.5. Result Computation (Final Step):

**Result Enable:**

```verilog
result_en = 1;
```

- Computes and outputs the final result.
- Stops further processing after generating the output.

### 4. Address Calculations:

Dynamic memory addresses are calculated based on:

1. **Level (lvl, slvl):**

```verilog
memstartw_lvl = memstartw+lvl+slvl*(4*(filt+1))+num*(filt+1)*num_conv;
```

2. **Matrix Dimensions:**

```verilog
matrix2 = matrix * matrix;
```

3. **Pointer Updates:**

- Handles changes in input and output memory addresses for each computation stage.

### 5. Outputs and Signals:

1. **Result Output:**

```verilog
assign RESULT = (STOP)?res_out:4'b1111;
```

- Provides the final result or error code (`1111`).

2. **Memory Read/Write Signals:**

```verilog
assign re_p = (conv_en==1)?re_conv:((maxp_en==1)?re_maxp:0);
```

- Routes read and write signals based on the active computation stage.

### 6. Summary:

- **Initialization:** Prepares the system.
- **Processing Layers:** Executes convolution, pooling, and dense computations.
- **Dynamic Addressing:** Efficiently handles memory addressing based on computation type and size.
- **Control Signals:** Coordinates transitions and enables/disables operations as needed.
- **Final Output:** Provides classification results or stops processing based on completion flags.



## Pictures of Circuit

![Circuit1](images/Circuit1.jpg)

![Circuit2](images/Circuit2.jpg)

![Circuit3](images/Circuit3.jpg)



## Demo Video with Detection

[Video1.mp4](https://husteduvn-my.sharepoint.com/:v:/g/personal/hai_cnh213609_sis_hust_edu_vn/EeQMdtuOlTJKvW4hsyyp_ZMBOWEdEe8EDmGqAdIqqnXWIg?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=DBtQWF)

[Video2.mp4](https://husteduvn-my.sharepoint.com/:v:/g/personal/hai_cnh213609_sis_hust_edu_vn/EbFS03EQIyZNlvDAxNrT73sB-0EvKm0yniBdiSgNoiokUQ?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=udSaAi)
