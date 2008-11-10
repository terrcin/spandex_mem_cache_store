class SpandexMemCacheStore < ActiveSupport::Cache::Store
  # this allows caching of the fact that there is nothing in the cache
  CACHED_NULL = 'spandex:cached_null'

  def initialize(*addresses)
    @hash = Hash.new
    @memcache_store = ActiveSupport::Cache::MemCacheStore.new(*addresses)
  end

  def read(key, options = nil)
    value = @hash[key]
    if value == CACHED_NULL
      value = nil
    elsif value.nil?
      value = @memcache_store.read(key, options)
      @hash[key] = value || CACHED_NULL
    end
    value
  end
  
  alias :get :read

  # Set key = value. Pass :unless_exist => true if you don't 
  # want to update the cache if the key is already set. 
  def write(key, value, options = nil)
    @memcache_store.write(key, (@hash[key] = value || CACHED_NULL), options)
  end
  
  alias :set :write

  def delete(key, options = nil)
    @hash[key] = CACHED_NULL
    @memcache_store.delete(key, options)
  end

  def exist?(key, options = nil)
    # memcache_store just does a read here, so lets just do that, and cache the result
    !read(key, options).nil?
  end

  def increment(key, amount = 1)     
    # don't do any local caching at present, just pass through  
    @memcache_store.increment(key, amount)
  end

  def decrement(key, amount = 1)
    # don't do any local caching at present, just pass through  
    @memcache_store.decrement(key, amount)
  end        
  
  def delete_matched(matcher, options = nil)
    # don't do any local caching at present, just pass through.
    # memcache_store doesn't support this so it throws an error
    @memcache_store.delete_matched(matcher, options)
  end        
  
  def clear_local
    # calling @hash.clear is something like 20x slower than just using a new hash
    @hash = Hash.new
  end        
  
  def clear
    clear_local
    @memcache_store.clear
  end
  
  def stats
    @memcache_store.stats
  end

end

class CGI
  class Session

    class SpandexMemCacheStore #< class #Cgi::Session

      # MemCache-based session storage class.
      #
      # This builds upon the top-level MemCache class provided by the
      # library file memcache.rb.  Session data is marshalled and stored
      # in a memcached cache.

      def check_id(id) #:nodoc:#
        /[^0-9a-zA-Z]+/ =~ id.to_s ? false : true
      end

      # Create a new CGI::Session::MemCache instance
      #
      # This constructor is used internally by CGI::Session. The
      # user does not generally need to call it directly.
      #
      # +session+ is the session for which this instance is being
      # created. The session id must only contain alphanumeric
      # characters; automatically generated session ids observe
      # this requirement.
      #
      # +options+ is a hash of options for the initializer. The
      # following options are recognized:
      #
      # cache::  an instance of a MemCache client to use as the
      #      session cache.
      #
      # expires:: an expiry time value to use for session entries in
      #     the session cache. +expires+ is interpreted in seconds
      #     relative to the current time if itís less than 60*60*24*30
      #     (30 days), or as an absolute Unix time (e.g., Time#to_i) if
      #     greater. If +expires+ is +0+, or not passed on +options+,
      #     the entry will never expire.
      #
      # This session's memcache entry will be created if it does
      # not exist, or retrieved if it does.
      def initialize(session, options = {})
        id = session.session_id
        unless check_id(id)
          raise ArgumentError, "session_id '%s' is invalid" % id
        end
        #@cache = Rails.cache #options['cache'] || MemCache.new('localhost')
        @expires = options['expires'] || 0
        @session_key = "session:#{id}"
        @session_data = {}
        # Add this key to the store if haven't done so yet
        unless Rails.cache.read(@session_key)
          update
        end
      end

      # Restore session state from the session's memcache entry.
      #
      # Returns the session state as a hash.
      def restore
        @session_data = Rails.cache.read(@session_key) || {}
      end

      # Save session state to the session's memcache entry.
      def update
        Rails.cache.write(@session_key, @session_data, {:expires_in => @expires})
      end

      # Update and close the session's memcache entry.
      def close
        update
      end

      # Delete the session's memcache entry.
      def delete
        Rails.cache.delete(@session_key)
        @session_data = {}
      end

      def data
        @session_data
      end

    end

  end
end