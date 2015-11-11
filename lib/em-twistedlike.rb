# -*- coding:utf-8 -*-

# em-twistedlike - Implement some of Twisted's features within EventMachine
# Copyleft 2015 - Nicolas AGIUS <nicolas.agius@lps-it.fr>

###########################################################################
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
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###########################################################################

require 'eventmachine'

# This Monkeypatch implement some of Twisted's defer funtionnalities to EventMachine Deferrable.
# This provide convenient helper and also a better exception management during callbacks execution, 
# ie, the double callback cross-chains of Twisted.
#
# Each Exception raised during this chain execution is wrapped into a Failure object and passed
# to the next error callback. The original exception can be retrieved with {Failure#value}.
#
# I suggest you to be familiar with the behavior of Twisted. For more information, 
# see {http://twistedmatrix.com/documents/current/core/howto/defer.html#visual-explanation}

module EventMachine

	# Execute the block in a thread with defer() and wrap it into a Deferrable with exception handling.
	# See {http://twistedmatrix.com/documents/current/api/twisted.internet.threads.deferToThread.html}
	#
	# @param block [Block]
	# @return [Deferrable]
	def self.defer_to_thread(&block)
		d=EM::DefaultDeferrable.new

		operation = proc {
			begin
				block.call
			rescue StandardError => e
				d.fail(e)
			end
		}

		EM.defer(operation, proc { |result| d.succeed(result) })

		return d
	end

	module Deferrable
		# Add the block to the success callback chain
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.Deferred.addCallback.html}
		#
		# @param block [Block] The success callback
		def add_callback(&block)
			add_callbacks(block, proc { |args| args })
		end

		# Add the block to the error callback chain
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.Deferred.addErrback.html}
		#
		# @param block [Block] The error callback
		def add_errback(&block)
			add_callbacks(proc { |args| args }, block)
		end

		# Add the block to both success and error callback chain
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.Deferred.addBoth.html}
		#
		# @param block [Block] The callback
		def add_both(&block)
			add_callbacks(block, block)
		end

		# Add the block to both success and error callback chain
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.Deferred.addCallbacks.html}
		#
		# @param success [Proc] The success callback
		# @param error [Proc] The error callback
		def add_callbacks(success, error)
			def call(block)
				begin
					result = block.call(*@deferred_args)
					if result.kind_of? Exception
						fail(result)
					else
						succeed(result)
					end
				rescue StandardError => e
					fail(e)
				end
			end

			if @deferred_status.nil? or @deferred_status == :unknown
				callback {
					@errbacks.pop unless @errbacks.nil?
					call(success)
				}
				errback {
					@callbacks.pop unless @callbacks.nil?
					call(error)
				}
			else
				# Run the corresponding block immediately if the Defer has already been fired
				call(@deferred_status == :succeeded ? success : error)
			end
		end
		
		# Trigger the errback chain while wrapping the argument in a Failure object.
		# - If there is no more error callback, the Failure will be raised.
		# - If multiple arguments are provided, the default behavior of EM will be used.
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.Deferred.errback.html}
		#
		# @param args [Object, Failure] Usually an object representing an error
		def fail(*args)
			if args.size > 1
				# Multiple arguments: default EM behavior
				set_deferred_status :failed, *args
			else
				# One argument: convert to Exception
				reason = args.first

				if not reason.instance_of? Failure
					reason = Failure.new(reason)
				end

				# Raise exception if there is no errback to handle it
				if @errbacks.nil? || @errbacks.empty?
					raise reason
				else
					set_deferred_status :failed, reason
				end
			end
		end
	
		# TODO: http://twistedmatrix.com/documents/current/api/twisted.internet.defer.maybeDeferred.html
		def maybe_deferred
			raise NotImplementedError
		end

		# TODO: http://twistedmatrix.com/documents/current/core/howto/defer.html#chaining-deferreds
		def chain_deferred(d)
			raise NotImplementedError
		end

	end

	class DefaultDeferrable
		include Deferrable

		# Return a Deferrable that has already had {#fail} called.
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.fail.html}
		#
		# @param arg [Object, Failure] (see #fail)
		# @return [Deferrable]
		def self.failed(arg)
			d = new
			d.fail(arg)
			return d
		end
	
		# Return a Deferrable that has already had {#succeed} called.
		# See {http://twistedmatrix.com/documents/current/api/twisted.internet.defer.succeed.html}
		#
		# @param arg [Object] (see #succeed)
		# @return [Deferrable]
		def self.succeeded(arg)
			d = new
			d.succeed(arg)
			return d
		end
	end

	# DeferrableList is a tool for collecting the results of several Deferrables.
	# When they have all completed, the success callback will be fired with an Array of
	# couple [success, result]. The order of the results is the same than the deferrables array.
	#
	# @note The errback chain will never be fired.
	# @see {https://twistedmatrix.com/documents/current/api/twisted.internet.defer.DeferredList.html}
	class DeferrableList
		include Deferrable

		# Create a new DeferrableList
		#
		# @params deferrables [Array<Deferrable>] Array of Deferrable to merge
		# @return [Deferrable] with result [Array<Array<Boolean, Object>>]
		def initialize(deferrables)
			@results = []
			@results_count = deferrables.size

			if @results_count == 0
				succeed([]) # Fire immediately if no deferrable provided
			else
				deferrables.each_with_index { |deferrable, index| 
					deferrable.add_callbacks( proc { |result|
						@results[index] = [true, result]
						result
					}, proc { |reason|
						@results[index] = [false, reason]
						reason
					})

					deferrable.add_both { |result|
						@results_count -= 1  
						succeed(@results) if @results_count <= 0
						result
					}
				}
			end
		end
	end

	# Used to pass an object as value of an exception
	class Failure < StandardError
		attr_reader :value

		# Create a new Failure
		#
		# @param value [Object] Any object, usually representing an error
		def initialize(value = nil)
			super("#{value.class} - #{value}")
			self.value = value
		end
	end
end

# vim: ts=4:sw=4:ai:noet
