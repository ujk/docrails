require 'abstract_unit'

class ReloaderTest < Test::Unit::TestCase
  Reloader = ActionDispatch::Reloader

  def test_prepare_callbacks
    a = b = c = nil
    Reloader.to_prepare { |*args| a = b = c = 1 }
    Reloader.to_prepare { |*args| b = c = 2 }
    Reloader.to_prepare { |*args| c = 3 }

    # Ensure to_prepare callbacks are not run when defined
    assert_nil a || b || c

    # Run callbacks
    call_and_return_body

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
  end

  def test_to_prepare_with_identifier_replaces
    a = b = 0
    Reloader.to_prepare(:unique_id) { |*args| a = b = 1 }
    Reloader.to_prepare(:unique_id) { |*args| a = 2 }

    call_and_return_body
    assert_equal 2, a
    assert_equal 0, b
  end

  class MyBody < Array
    def initialize(&block)
      @on_close = block
    end

    def foo
      "foo"
    end

    def bar
      "bar"
    end

    def close
      @on_close.call if @on_close
    end
  end

  def test_returned_body_object_always_responds_to_close
    body = call_and_return_body
    assert body.respond_to?(:close)
  end

  def test_returned_body_object_behaves_like_underlying_object
    body = call_and_return_body do
      b = MyBody.new
      b << "hello"
      b << "world"
      [200, { "Content-Type" => "text/html" }, b]
    end
    assert_equal 2, body.size
    assert_equal "hello", body[0]
    assert_equal "world", body[1]
    assert_equal "foo", body.foo
    assert_equal "bar", body.bar
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    body = call_and_return_body do
      b = MyBody.new do
        close_called = true
      end
      [200, { "Content-Type" => "text/html" }, b]
    end
    body.close
    assert close_called
  end

  def test_returned_body_object_responds_to_all_methods_supported_by_underlying_object
    body = call_and_return_body do
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    end
    assert body.respond_to?(:size)
    assert body.respond_to?(:each)
    assert body.respond_to?(:foo)
    assert body.respond_to?(:bar)
  end

  def test_cleanup_callbacks_are_called_when_body_is_closed
    cleaned = false
    Reloader.to_cleanup { cleaned = true }

    body = call_and_return_body
    assert !cleaned

    body.close
    assert cleaned
  end

  def test_prepare_callbacks_arent_called_when_body_is_closed
    prepared = false
    Reloader.to_prepare { prepared = true }

    body = call_and_return_body
    prepared = false

    body.close
    assert !prepared
  end

  def test_manual_reloading
    prepared = cleaned = false
    Reloader.to_prepare { prepared = true }
    Reloader.to_cleanup { cleaned  = true }

    Reloader.prepare!
    assert prepared
    assert !cleaned

    prepared = cleaned = false
    Reloader.cleanup!
    assert !prepared
    assert cleaned

    prepared = cleaned = false
    Reloader.reload!
    assert prepared
    assert cleaned
  end

  private
    def call_and_return_body(&block)
      @reloader ||= Reloader.new(block || proc {[200, {}, 'response']})
      @reloader.call({'rack.input' => StringIO.new('')})[2]
    end
end
