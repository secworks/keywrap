//======================================================================
//
// keywrap.v
// ---------
// RFC3394 keywrap core.
// The core works on blocks of 64 bits. The supported key lengths
// are 128 and 256 bits.
//
// TODO: Refactor this to have the real functionality in a
// keywrap_core module and the API in this module.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2015 Assured AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module keywrap(
               input wire           clk,
               input wire           reset_n,

               input wire           cs,
               input wire           we,

               input wire  [7 : 0]  address,
               input wire  [31 : 0] write_data,
               output wire [31 : 0] read_data,
               output wire          error
              );

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam DEBUG            = 0;

  localparam ADDR_NAME0       = 8'h00;
  localparam ADDR_NAME1       = 8'h01;
  localparam ADDR_VERSION     = 8'h02;

  localparam ADDR_CTRL        = 8'h08;
  localparam CTRL_INIT_BIT    = 0;
  localparam CTRL_NEXT_BIT    = 1;

  localparam ADDR_STATUS      = 8'h09;
  localparam STATUS_READY_BIT = 0;
  localparam STATUS_VALID_BIT = 1;

  localparam ADDR_CONFIG      = 8'h0a;
  localparam CTRL_ENCDEC_BIT  = 0;
  localparam CTRL_KEYLEN_BIT  = 1;

  localparam ADDR_KEY0        = 8'h10;
  localparam ADDR_KEY1        = 8'h11;
  localparam ADDR_KEY2        = 8'h12;
  localparam ADDR_KEY3        = 8'h13;
  localparam ADDR_KEY4        = 8'h14;
  localparam ADDR_KEY5        = 8'h15;
  localparam ADDR_KEY6        = 8'h16;
  localparam ADDR_KEY7        = 8'h17;

  localparam ADDR_BLOCK0      = 8'h20;
  localparam ADDR_BLOCK1      = 8'h21;

  localparam ADDR_RESULT0     = 8'h30;
  localparam ADDR_RESULT1     = 8'h31;

  localparam CORE_NAME0       = 32'h6b657977; // "keyw"
  localparam CORE_NAME1       = 32'h72617020; // "rap "
  localparam CORE_VERSION     = 32'h302e3032; // "0.02"


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg init_reg;
  reg init_new;
  reg init_we;
  reg init_set;

  reg next_reg;
  reg next_new;
  reg next_we;
  reg next_set;

  reg encdec_reg;
  reg keylen_reg;
  reg config_we;

  reg [31 : 0] block0_reg;
  reg          block0_we;
  reg [31 : 0] block1_reg;
  reg          block1_we;

  reg [31 : 0] key0_reg;
  reg          key0_we;
  reg [31 : 0] key1_reg;
  reg          key1_we;
  reg [31 : 0] key2_reg;
  reg          key2_we;
  reg [31 : 0] key3_reg;
  reg          key3_we;
  reg [31 : 0] key4_reg;
  reg          key4_we;
  reg [31 : 0] key5_reg;
  reg          key5_we;
  reg [31 : 0] key6_reg;
  reg          key6_we;
  reg [31 : 0] key7_reg;
  reg          key7_we;

  reg [63 : 0] result_reg;
  reg          valid_reg;
  reg          ready_reg;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]   tmp_read_data;
  reg            tmp_error;

  reg [63 : 0]   a_reg;
  reg [63 : 0]   a_new;
  reg            a_we;
  reg            a_init;
  reg            a_next;

  wire           core_encdec;
  wire           core_init;
  wire           core_next;
  wire           core_ready;
  wire [255 : 0] core_key;
  wire           core_keylen;
  wire [127 : 0] core_block;
  wire [127 : 0] core_result;
  wire           core_valid;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;
  assign error     = tmp_error;

  assign core_key = {key0_reg, key1_reg, key2_reg, key3_reg,
                     key4_reg, key5_reg, key6_reg, key7_reg};

  assign core_block  = {block0_reg, block1_reg, block2_reg, block3_reg};
  assign core_init   = init_reg;
  assign core_next   = next_reg;
  assign core_encdec = encdec_reg;
  assign core_keylen = keylen_reg;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  aes_core aes_core_inst(
                         .clk(clk),
                         .reset_n(reset_n),

                         .encdec(core_encdec),
                         .init(core_init),
                         .next(core_next),
                         .ready(core_ready),

                         .key(core_key),
                         .keylen(core_keylen),

                         .block(core_block),
                         .result(core_result),
                         .result_valid(core_valid)
                        );


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          block0_reg <= 32'h00000000;
          block1_reg <= 32'h00000000;

          key0_reg   <= 32'h00000000;
          key1_reg   <= 32'h00000000;
          key2_reg   <= 32'h00000000;
          key3_reg   <= 32'h00000000;
          key4_reg   <= 32'h00000000;
          key5_reg   <= 32'h00000000;
          key6_reg   <= 32'h00000000;
          key7_reg   <= 32'h00000000;

          init_reg   <= 0;
          next_reg   <= 0;
          encdec_reg <= 0;
          keylen_reg <= 0;

          result_reg <= 128'h00000000000000000000000000000000;
          valid_reg  <= 0;
          ready_reg  <= 0;
        end
      else
        begin
          ready_reg      <= core_ready;
          valid_reg      <= core_valid;
          result_reg     <= core_result;

          if (init_we)
            begin
              init_reg <= init_new;
            end

          if (next_we)
            begin
              next_reg <= next_new;
            end

          if (config_we)
            begin
              encdec_reg <= write_data[CTRL_ENCDEC_BIT];
              keylen_reg <= write_data[CTRL_KEYLEN_BIT];
            end

          if (key0_we)
            begin
              key0_reg <= write_data;
            end

          if (key1_we)
            begin
              key1_reg <= write_data;
            end

          if (key2_we)
            begin
              key2_reg <= write_data;
            end

          if (key3_we)
            begin
              key3_reg <= write_data;
            end

          if (key4_we)
            begin
              key4_reg <= write_data;
            end

          if (key5_we)
            begin
              key5_reg <= write_data;
            end

          if (key6_we)
            begin
              key6_reg <= write_data;
            end

          if (key7_we)
            begin
              key7_reg <= write_data;
            end

          if (block0_we)
            begin
              block0_reg <= write_data;
            end

          if (block1_we)
            begin
              block1_reg <= write_data;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // flag_ctrl
  //
  // Logic to set and the automatically reset init- and
  // next flags that has been set.
  //----------------------------------------------------------------
  always @*
    begin : flag_reset
      init_new = 0;
      init_we  = 0;
      next_new = 0;
      next_we  = 0;

      if (init_set)
        begin
          init_new = 1;
          init_we  = 1;
        end
      else if (init_reg)
        begin
          init_new = 0;
          init_we  = 1;
        end

      if (next_set)
        begin
          next_new = 1;
          next_we  = 1;
        end
      else if (next_reg)
        begin
          next_new = 0;
          next_we  = 1;
        end
    end

  //----------------------------------------------------------------
  // Datapath. Or a register logic, if we do this separately.
  //----------------------------------------------------------------
  always @*
    begin
      a_new = 64'h0000000000000000;
      a_we  = 1'b0;

      if (a_init)
        begin
          a_new = 64'ha6a6a6a6a6a6a6a6;
          a_we  = 1'b1;
        end
    end


  //----------------------------------------------------------------
  // api
  //
  // The interface command decoding logic.
  //----------------------------------------------------------------
  always @*
    begin : api
      init_set      = 0;
      next_set      = 0;
      config_we     = 0;
      key0_we       = 0;
      key1_we       = 0;
      key2_we       = 0;
      key3_we       = 0;
      key4_we       = 0;
      key5_we       = 0;
      key6_we       = 0;
      key7_we       = 0;
      block0_we     = 0;
      block1_we     = 0;
      block2_we     = 0;
      block3_we     = 0;
      tmp_read_data = 32'h00000000;
      tmp_error     = 0;

      if (cs)
        begin
          if (we)
            begin
              case (address)
                // Write operations.
                ADDR_CTRL:
                  begin
                    init_set = write_data[CTRL_INIT_BIT];
                    next_set = write_data[CTRL_NEXT_BIT];
                  end

                ADDR_CONFIG:
                  begin
                    config_we = 1;
                  end

                ADDR_KEY0:
                  begin
                    key0_we = 1;
                  end

                ADDR_KEY1:
                  begin
                    key1_we = 1;
                  end

                ADDR_KEY2:
                  begin
                    key2_we = 1;
                  end

                ADDR_KEY3:
                  begin
                    key3_we = 1;
                  end

                ADDR_KEY4:
                  begin
                    key4_we = 1;
                  end

                ADDR_KEY5:
                  begin
                    key5_we = 1;
                  end

                ADDR_KEY6:
                  begin
                    key6_we = 1;
                  end

                ADDR_KEY7:
                  begin
                    key7_we = 1;
                  end

                ADDR_BLOCK0:
                  begin
                    block0_we = 1;
                  end

                ADDR_BLOCK1:
                  begin
                    block1_we = 1;
                  end

                ADDR_BLOCK2:
                  begin
                    block2_we = 1;
                  end

                ADDR_BLOCK3:
                  begin
                    block3_we = 1;
                  end

                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end // if (we)

          else
            begin
              case (address)
                // Read operations.
                ADDR_NAME0:
                  begin
                    tmp_read_data = CORE_NAME0;
                  end

                ADDR_NAME1:
                  begin
                    tmp_read_data = CORE_NAME1;
                  end

                ADDR_VERSION:
                  begin
                    tmp_read_data = CORE_VERSION;
                  end

                ADDR_CTRL:
                  begin
                    tmp_read_data = {28'h0000000, keylen_reg, encdec_reg,
                                     next_reg, init_reg};
                  end

                ADDR_STATUS:
                  begin
                    tmp_read_data = {30'h00000000, valid_reg, ready_reg};
                  end

                ADDR_KEY0:
                  begin
                    tmp_read_data = key0_reg;
                  end

                ADDR_KEY1:
                  begin
                    tmp_read_data = key1_reg;
                  end

                ADDR_KEY2:
                  begin
                    tmp_read_data = key2_reg;
                  end

                ADDR_KEY3:
                  begin
                    tmp_read_data = key3_reg;
                  end

                ADDR_KEY4:
                  begin
                    tmp_read_data = key4_reg;
                  end

                ADDR_KEY5:
                  begin
                    tmp_read_data = key5_reg;
                  end

                ADDR_KEY6:
                  begin
                    tmp_read_data = key6_reg;
                  end

                ADDR_KEY7:
                  begin
                    tmp_read_data = key7_reg;
                  end

                ADDR_BLOCK0:
                  begin
                    tmp_read_data = block0_reg;
                  end

                ADDR_BLOCK1:
                  begin
                    tmp_read_data = block1_reg;
                  end

                ADDR_BLOCK2:
                  begin
                    tmp_read_data = block2_reg;
                  end

                ADDR_BLOCK3:
                  begin
                    tmp_read_data = block3_reg;
                  end

                ADDR_RESULT0:
                  begin
                    tmp_read_data = result_reg[127 : 96];
                  end

                ADDR_RESULT1:
                  begin
                    tmp_read_data = result_reg[95 : 64];
                  end

                ADDR_RESULT2:
                  begin
                    tmp_read_data = result_reg[63 : 32];
                  end

                ADDR_RESULT3:
                  begin
                    tmp_read_data = result_reg[31 : 0];
                  end

                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end
        end
    end // addr_decoder


  //----------------------------------------------------------------
  // keywrap_ctrl
  //
  // Control FSM for the keyrap core.
  //----------------------------------------------------------------
  always @*
    begin : keywrap_ctrl

    end

endmodule // keywrap

//======================================================================
// EOF keywrap.v
//======================================================================
