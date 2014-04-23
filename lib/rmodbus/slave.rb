# RModBus - free implementation of ModBus protocol on Ruby.
#
# Copyright (C) 2008-2011  Timin Aleksey
# Copyright (C) 2010  Kelley Reynolds
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

module ModBus
  class Slave
    include Errors
    include Debug
    include Options
    # Number of times to retry on read and read timeouts
    attr_accessor :uid
    Exceptions = {
          1 => IllegalFunction.new("The function code received in the query is not an allowable action for the server"),
          2 => IllegalDataAddress.new("The data address received in the query is not an allowable address for the server"),
          3 => IllegalDataValue.new("A value contained in the query data field is not an allowable value for server"),
          4 => SlaveDeviceFailure.new("An unrecoverable error occurred while the server was attempting to perform the requested action"),
          5 => Acknowledge.new("The server has accepted the request and is processing it, but a long duration of time will be required to do so"),
          6 => SlaveDeviceBus.new("The server is engaged in processing a long duration program command"),
          8 => MemoryParityError.new("The extended file area failed to pass a consistency check")
    }
    def initialize(uid, io)
	    @uid = uid
      @io = io
    end

    # Returns a ModBus::ReadWriteProxy hash interface for coils
    #
    # @example
    #  coils[addr] => [1]
    #  coils[addr1..addr2] => [1, 0, ..]
    #  coils[addr] = 0 => [0]
    #  coils[addr1..addr2] = [1, 0, ..] => [1, 0, ..]
    #
    # @return [ReadWriteProxy] proxy object
    def coils
      ModBus::ReadWriteProxy.new(self, :coil)
    end

    # Read coils
    #
    # @example
    #  read_coils(addr, ncoils) => [1, 0, ..]
    #
    # @param [Integer] addr address first coil
    # @param [Integer] ncoils number coils
    # @return [Array] coils
    def read_coils(addr, ncoils)
      query("\x1" + addr.to_word + ncoils.to_word).unpack_bits[0..ncoils-1]
    end
    alias_method :read_coil, :read_coils

    # Write a single coil
    #
    # @example
    #  write_single_coil(1, 0) => self
    #
    # @param [Integer] addr address coil
    # @param [Integer] val value coil (0 or other)
    # @return self
    def write_single_coil(addr, val)
      if val == 0
        query("\x5" + addr.to_word + 0.to_word)
      else
        query("\x5" + addr.to_word + 0xff00.to_word)
      end
      self
    end
    alias_method :write_coil, :write_single_coil

    # Write multiple coils
    #
    # @example
    #  write_multiple_coils(1, [0,1,0,1]) => self
    #
    # @param [Integer] addr address first coil
    # @param [Array] vals written coils
    def write_multiple_coils(addr, vals)
      nbyte = ((vals.size-1) >> 3) + 1
      sum = 0
      (vals.size - 1).downto(0) do |i|
        sum = sum << 1
        sum |= 1 if vals[i] > 0
      end

      s_val = ""
      nbyte.times do
        s_val << (sum & 0xff).chr
        sum >>= 8
      end

      query("\xf" + addr.to_word + vals.size.to_word + nbyte.chr + s_val)
      self
    end
    alias_method :write_coils, :write_multiple_coils

    # Returns a ModBus::ReadOnlyProxy hash interface for discrete inputs
    #
    # @example
    #  discrete_inputs[addr] => [1]
    #  discrete_inputs[addr1..addr2] => [1, 0, ..]
    #
    # @return [ReadOnlyProxy] proxy object
    def discrete_inputs
      ModBus::ReadOnlyProxy.new(self, :discrete_input)
    end

    # Read discrete inputs
    #
    # @example
    #  read_discrete_inputs(addr, ninputs) => [1, 0, ..]
    #
    # @param [Integer] addr address first input
    # @param[Integer] ninputs number inputs
    # @return [Array] inputs
    def read_discrete_inputs(addr, ninputs)
      query("\x2" + addr.to_word + ninputs.to_word).unpack_bits[0..ninputs-1]
    end
    alias_method :read_discrete_input, :read_discrete_inputs

    # Returns a read/write ModBus::ReadOnlyProxy hash interface for coils
    #
    # @example
    #  input_registers[addr] => [1]
    #  input_registers[addr1..addr2] => [1, 0, ..]
    #
    # @return [ReadOnlyProxy] proxy object
    def input_registers
      ModBus::ReadOnlyProxy.new(self, :input_register)
    end

    # Read input registers
    #
    # @example
    #  read_input_registers(1, 5) => [1, 0, ..]
    #
    # @param [Integer] addr address first registers
    # @param [Integer] nregs number registers
    # @return [Array] registers
    def read_input_registers(addr, nregs)
      query("\x4" + addr.to_word + nregs.to_word).unpack('n*')
    end
    alias_method :read_input_register, :read_input_registers

    # Returns a ModBus::ReadWriteProxy hash interface for holding registers
    #
    # @example
    #  holding_registers[addr] => [123]
    #  holding_registers[addr1..addr2] => [123, 234, ..]
    #  holding_registers[addr] = 123 => 123
    #  holding_registers[addr1..addr2] = [234, 345, ..] => [234, 345, ..]
    #
    # @return [ReadWriteProxy] proxy object
    def holding_registers
      ModBus::ReadWriteProxy.new(self, :holding_register)
    end

    # Read holding registers
    #
    # @example
    #  read_holding_registers(1, 5) => [1, 0, ..]
    #
    # @param [Integer] addr address first registers
    # @param [Integer] nregs number registers
    # @return [Array] registers
    def read_holding_registers(addr, nregs)
      query("\x3" + addr.to_word + nregs.to_word).unpack('n*')
    end
    alias_method :read_holding_register, :read_holding_registers

    # Write a single holding register
    #
    # @example
    #  write_single_register(1, 0xaa) => self
    #
    # @param [Integer] addr address registers
    # @param [Integer] val written to register
    # @return self
    def write_single_register(addr, val)
      query("\x6" + addr.to_word + val.to_word)
      self
    end
    alias_method :write_holding_register, :write_single_register


    # Write multiple holding registers
    #
    # @example
    #  write_multiple_registers(1, [0xaa, 0]) => self
    #
    # @param [Integer] addr address first registers
    # @param [Array] val written registers
    # @return self
    def write_multiple_registers(addr, vals)
      s_val = ""
      vals.each do |reg|
        s_val << reg.to_word
      end

      query("\x10" + addr.to_word + vals.size.to_word + (vals.size * 2).chr + s_val)
      self
    end
    alias_method :write_holding_registers, :write_multiple_registers

    # Mask a holding register
    #
    # @example
    #   mask_write_register(1, 0xAAAA, 0x00FF) => self
    # @param [Integer] addr address registers
    # @param [Integer] and_mask mask for AND operation
    # @param [Integer] or_mask mask for OR operation
    def mask_write_register(addr, and_mask, or_mask)
      query("\x16" + addr.to_word + and_mask.to_word + or_mask.to_word)
      self
    end

    # Request pdu to slave device
    #
    # @param [String] pdu request to slave
    # @return [String] received data
    #
    # @raise [ResponseMismatch] the received echo response differs from the request
    # @raise [ModBusTimeout] timed out during read attempt
    # @raise [ModBusException] unknown error
    # @raise [IllegalFunction] function code received in the query is not an allowable action for the server
    # @raise [IllegalDataAddress] data address received in the query is not an allowable address for the server
    # @raise [IllegalDataValue] value contained in the query data field is not an allowable value for server
    # @raise [SlaveDeviceFailure] unrecoverable error occurred while the server was attempting to perform the requested action
    # @raise [Acknowledge] server has accepted the request and is processing it, but a long duration of time will be required to do so
    # @raise [SlaveDeviceBus] server is engaged in processing a long duration program command
    # @raise [MemoryParityError] extended file area failed to pass a consistency check
    def query(request)
      tried = 0
      response = ""
      begin
        timeout(@read_retry_timeout, ModBusTimeout) do
	  if @io.is_a?(TCPSocket)
            send_pdu(request)
            response = read_pdu
          else
            @io.rts = 1 # set ready to send flag to true
            send_pdu(request) # send request
            Termios.tcdrain(@io) # wait till all data went through io
            @io.rts = 0 # set ready to send flag to false (meaning we are ready to read)
            response = read_pdu # read data
          end
        end
      rescue ModBusTimeout => err
        log "Timeout of read operation: (#{@read_retries - tried})"
        tried += 1
        retry unless tried >= @read_retries
        raise ModBusTimeout.new, "Timed out during read attempt"
      end

      return nil if response.size == 0

      read_func = response.getbyte(0)
      if read_func >= 0x80
        exc_id = response.getbyte(1)
        raise Exceptions[exc_id] unless Exceptions[exc_id].nil?

        raise ModBusException.new, "Unknown error"
      end

      check_response_mismatch(request, response) if raise_exception_on_mismatch
      response[2..-1]
    end

    private
    def check_response_mismatch(request, response)
      read_func = response.getbyte(0)
      data = response[2..-1]
      #Mismatch functional code
      send_func = request.getbyte(0)
      if read_func != send_func
        msg = "Function code is mismatch (expected #{send_func}, got #{read_func})"
      end

      case read_func
      when 1,2
        bc = request.getword(3)/8 + 1
        if data.size != bc
          msg = "Byte count is mismatch (expected #{bc}, got #{data.size} bytes)"
        end
      when 3,4
        rc = request.getword(3) 
        if data.size/2 != rc
          msg = "Register count is mismatch (expected #{rc}, got #{data.size/2} regs)"
        end
      when 5,6
        exp_addr = request.getword(1)
        got_addr = response.getword(1)
        if exp_addr != got_addr
          msg = "Address is mismatch (expected #{exp_addr}, got #{got_addr})"
        end

        exp_val = request.getword(3)
        got_val = response.getword(3)
        if exp_val != got_val
          msg = "Value is mismatch (expected 0x#{exp_val.to_s(16)}, got 0x#{got_val.to_s(16)})"
        end
      when 15,16
        exp_addr = request.getword(1)
        got_addr = response.getword(1)
        if exp_addr != got_addr
          msg = "Address is mismatch (expected #{exp_addr}, got #{got_addr})"
        end
      
        exp_quant = request.getword(3)
        got_quant = response.getword(3)
        if exp_quant != got_quant
          msg = "Quantity is mismatch (expected #{exp_quant}, got #{got_quant})"
        end
      else
        warn "Fuiction (#{read_func}) is not supported raising response mismatch"
      end

      raise ResponseMismatch.new(msg, request, response) if msg
    end
  end
end
