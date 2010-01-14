# RModBus - free implementation of ModBus protocol on Ruby.
#
# Copyright (C) 2008  Timin Aleksey
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
require 'rmodbus/parsers'
require 'gserver'


module ModBus
  class TCPServer < GServer
    include Parsers
    
    attr_accessor :coils, :discret_inputs, :holding_registers, :input_registers

    
    def initialize(port = 502, uid = 1)
      @coils = []
      @discret_inputs = []
      @holding_registers =[]
      @input_registers = []
      @uid = uid
      super(port)
    end

    def serve(io)
      loop do
        req = io.read(7)
        if req[2,2] != "\x00\x00" or req.getbyte(6) != @uid
          io.close
          break
        end
 
        tr = req[0,2]
        len = req[4,2].unpack('n')[0]
        req = io.read(len - 1)

        params = exec_req(req, @coils, @discret_inputs, @holding_registers, @input_registers)

        if params[:err] ==  0
          resp = tr + "\0\0" + (params[:res].size + 1).to_word + @uid.chr + params[:res]
        else
          resp = tr + "\0\0\0\3" + @uid.chr + (params[:func] | 0x80).chr + params[:err].chr
        end 
        io.write resp
     end
    end
  end
end
