require 'spec_helper'

RSpec.describe IdempotentRequest::RequestManager do
  let(:url) { 'http://qonto.eu' }
  let(:default_env) { env_for(url) }
  let(:env) { default_env }
  let(:request) { IdempotentRequest::Request.new(env) }
  let!(:memory_storage) { @memory_storage ||= IdempotentRequest::MemoryStorage.new }
  let(:request_storage) { described_class.new(request, { storage: memory_storage }) }

  before do
    allow(request).to receive(:key).and_return('data-key')
    memory_storage.clear
  end

  describe '#read' do
    context 'when there is no data' do
      it 'should return nil' do
        expect(request_storage.read).to be_nil
      end
    end

    context 'when there is data' do
      let(:data) do
        [200, {}, 'body']
      end

      let(:payload) do
        Oj.dump({
          status: data[0],
          headers: data[1],
          response: data[2]
        })
      end

      before do
        memory_storage.write(request.key, payload)
      end

      it 'should return data' do
        expect(request_storage.read).to eq(data)
      end

      context 'when callback is defined' do
        let(:request_storage) { described_class.new(request, storage: memory_storage, callback: IdempotencyCallback) }

        it 'should be called' do
          callback = double
          expect(IdempotencyCallback).to receive(:new).with(request).and_return(callback)
          expect(callback).to receive(:detected).with(key: request.key)
          expect(request_storage.read).to eq(data)
        end
      end

      context 'when read with different key' do
        context 'for the old key' do
          it 'should return data' do
            expect(request_storage.read).to eq(data)
          end
        end

        context 'for the new key' do
          before do
            allow(request).to receive(:key).and_return('data-key-2')
          end

          it 'should return nil' do
            expect(request_storage.read).to be_nil
          end
        end
      end
    end
  end

  describe '#write' do
    let(:payload) do
      Oj.dump({
        status: data[0],
        headers: data[1],
        response: data[2]
      })
    end

    context 'when status is 200' do
      let(:data) do
        [200, {}, 'body']
      end

      it 'should be stored' do
        request_storage.write(*data)
        expect(memory_storage.read(request.key)).to eq(payload)
      end
    end

    context 'when status is not 200' do
      let(:data) do
        [404, {}, 'body']
      end

      it 'should be stored' do
        request_storage.write(*data)
        expect(memory_storage.read(request.key)).to be_nil
      end
    end
  end

  class IdempotencyCallback
    def initialize(_); end

    def detected(_); end
  end
end
