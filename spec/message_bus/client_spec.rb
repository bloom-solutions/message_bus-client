RSpec.describe MessageBusClient do
  self::SERVER_BASE = 'http://127.0.0.1:9292'.freeze

  it 'has a version number' do
    expect(MessageBusClient::VERSION).not_to be nil
  end

  def write_message(message, user = 'message_bus_client')
    Excon.post(URI.join(self.class::SERVER_BASE, '/message').to_s,
               body: URI.encode_www_form(name: user, data: message),
               headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
  end

  subject { MessageBusClient.new(self.class::SERVER_BASE) }

  context 'when using long polling' do
    it 'connects to the server' do
      subject.start
      subject.stop
    end

    context 'when the connection times out' do
      it 'continues to long poll' do
        count = 0
        expect(subject).to receive(:request_parameters).and_wrap_original do |original, *args|
          count += 1
          parameters = original.call(*args)
          parameters[:read_timeout] = 0

          parameters
        end.at_least(:twice)

        subject.start
        sleep(1) until count > 1

        subject.stop
      end
    end

    it 'receives new messages by default (last_id of -1)' do
      subject.start

      text = "Hello World! #{Random.rand}"
      result = false
      subject.subscribe('/message') do |payload|
        result = true if payload['data'] == text
      end

      until result
        write_message(text) # Keep writing because the message bus might not have started.
        sleep(1)
      end
    end
  end

  context 'when using polling' do
    around(:each) do |example|
      begin
        old_long_polling = MessageBusClient.configuration.long_polling
        old_poll_interval = MessageBusClient.configuration.poll_interval
        MessageBusClient.configuration.poll_interval = 1
        MessageBusClient.configuration.long_polling = false
        example.call
      ensure
        MessageBusClient.configuration.poll_interval = old_poll_interval
        MessageBusClient.configuration.long_polling = old_long_polling
      end
    end

    it 'connects to the server' do
      subject.start
      subject.stop
    end

    it 'receives new messages by default (last_id of -1)' do
      subject.start

      text = "Hello World! #{Random.rand}"
      result = false
      subject.subscribe('/message') do |payload|
        result = true if payload['data'] == text
      end

      until result
        write_message(text) # Keep writing because the message bus might not have started.
        sleep(1)
      end
    end
  end

  it 'allows pausing messages' do
    subject.start
    subject.pause

    text = "Hello Pause! #{Random.rand}"
    result = false
    subject.subscribe('/message') {}
    expect(subject).to receive(:handle_messages).and_wrap_original do |original, *args|
      result = true if args.first && args.first.any? { |message| message['data']['data'] == text }
      original.call(*args)
    end.at_least(:once)

    until result
      write_message(text) # Keep writing because the message bus might not have started.
      sleep(1)
    end
    result = false

    subject.subscribe('/message') do |payload|
      result = result || payload['data'] == text
    end

    subject.resume
    expect(result).to eq(true)
  end

  it 'allows subscription exposing the message_id' do
    subject.start

    text = "Hello World! #{Random.rand}"
    result = false
    subject.subscribe('/message') do |payload, message_id|
      result = true if payload['data'] == text
      expect(message_id).to be_an Integer
    end

    until result
      write_message(text) # Keep writing because the message bus might not have started.
      sleep(1)
    end
  end
end
