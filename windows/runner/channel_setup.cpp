// =============================================================================
// channel_setup.cpp — Tutorial course: Windows native channel implementations
//
// Covers:
//   1. MethodChannel        — discrete request/response (StandardMethodCodec)
//   2. EventChannel         — continuous streaming from native to Dart
//   3. BasicMessageChannel  — two-way messaging (StandardMessageCodec)
//
// IMPORTANT — Windows codec availability:
//   The Flutter Windows C++ wrapper ships only two codecs:
//     • flutter::StandardMethodCodec   (used by MethodChannel internally)
//     • flutter::StandardMessageCodec  (used by BasicMessageChannel)
//   StringCodec and JsonMessageCodec are NOT available on Windows.
//   Use StandardMessageCodec and pass strings / maps as EncodableValue.
//   On the Dart side, use StandardMessageCodec() to match.
// =============================================================================

#include "channel_setup.h"

#include <windows.h>

#include <flutter/basic_message_channel.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/standard_message_codec.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <string>
#include <thread>

// ── File-scope typedefs (MSVC disallows local `using` aliases in lambdas) ─────
typedef NTSTATUS(WINAPI* RtlGetVersionFn)(OSVERSIONINFOEXW*);

// ── Helpers ───────────────────────────────────────────────────────────────────

static int GetInt(const EncodableMap& map, const std::string& key,
                  int fallback = 0) {
  auto it = map.find(EncodableVal(key));
  if (it == map.end()) return fallback;
  if (auto* p = std::get_if<int>(&it->second)) return *p;
  return fallback;
}

static std::string GetString(const EncodableMap& map, const std::string& key,
                              const std::string& fallback = "") {
  auto it = map.find(EncodableVal(key));
  if (it == map.end()) return fallback;
  if (auto* p = std::get_if<std::string>(&it->second)) return *p;
  return fallback;
}

// ─────────────────────────────────────────────────────────────────────────────

ChannelManager::ChannelManager(flutter::BinaryMessenger* messenger) {
  SetupMethodChannel(messenger);
  SetupBatteryEventChannel(messenger);
  SetupMessageChannel(messenger);
}

ChannelManager::~ChannelManager() {
  battery_stop_ = true;
  if (battery_thread_.joinable()) {
    battery_thread_.join();
  }
}

// =============================================================================
// 1. MethodChannel
// =============================================================================

void ChannelManager::SetupMethodChannel(flutter::BinaryMessenger* messenger) {
  method_channel_ =
      std::make_unique<flutter::MethodChannel<EncodableVal>>(
          messenger,
          "com.example.nativechannels/method",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableVal>& call,
         std::unique_ptr<flutter::MethodResult<EncodableVal>> result) {

        if (call.method_name() == "getDeviceInfo") {
          // Read Windows version via RtlGetVersion (not shimmed by compat layer)
          OSVERSIONINFOEXW osvi = {};
          osvi.dwOSVersionInfoSize = sizeof(osvi);
          HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
          RtlGetVersionFn fn = reinterpret_cast<RtlGetVersionFn>(
              GetProcAddress(ntdll, "RtlGetVersion"));
          std::string version = "Windows (unknown)";
          if (fn && fn(&osvi) == 0) {
            version = "Windows " + std::to_string(osvi.dwMajorVersion) +
                      "." + std::to_string(osvi.dwMinorVersion) +
                      " (build " + std::to_string(osvi.dwBuildNumber) + ")";
          }
          result->Success(EncodableVal(version));

        } else if (call.method_name() == "addNumbers") {
          const auto* args = std::get_if<EncodableMap>(call.arguments());
          if (!args) { result->Error("INVALID_ARGS", "Expected a map"); return; }
          result->Success(EncodableVal(GetInt(*args, "a") + GetInt(*args, "b")));

        } else if (call.method_name() == "readNativeFile") {
          const auto* args = std::get_if<EncodableMap>(call.arguments());
          std::string name = args ? GetString(*args, "filename") : "";
          if (name == "sample.txt") {
            result->Success(EncodableVal(
                std::string("Hello from Windows native!")));
          } else {
            result->Error("FILE_NOT_FOUND",
                          "No native file named: " + name);
          }

        } else if (call.method_name() == "heavyWork") {
          // Move result into the background thread via shared_ptr.
          auto shared = std::shared_ptr<flutter::MethodResult<EncodableVal>>(
              std::move(result));
          std::thread([shared]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            shared->Success(EncodableVal(
                std::string("Heavy work done on background thread!")));
          }).detach();

        } else {
          result->NotImplemented();
        }
      });
}

// =============================================================================
// 2. EventChannel — simulated battery (real: use Win32 GetSystemPowerStatus)
// =============================================================================

void ChannelManager::SetupBatteryEventChannel(
    flutter::BinaryMessenger* messenger) {
  battery_channel_ =
      std::make_unique<flutter::EventChannel<EncodableVal>>(
          messenger,
          "com.example.nativechannels/battery",
          &flutter::StandardMethodCodec::GetInstance());

  bool* stop = &battery_stop_;

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<EncodableVal>>(
      // onListen
      [this, stop](
          const EncodableVal* /*args*/,
          std::unique_ptr<flutter::EventSink<EncodableVal>>&& sink)
          -> std::unique_ptr<flutter::StreamHandlerError<EncodableVal>> {

        auto shared =
            std::shared_ptr<flutter::EventSink<EncodableVal>>(std::move(sink));
        *stop = false;

        battery_thread_ = std::thread([shared, stop]() {
          // Real: SYSTEM_POWER_STATUS sps; GetSystemPowerStatus(&sps);
          //       shared->Success(EncodableVal((int)sps.BatteryLifePercent));
          int level = 85;
          while (!*stop) {
            shared->Success(EncodableVal(level));
            level = (level > 5) ? level - 1 : 100;
            std::this_thread::sleep_for(std::chrono::seconds(1));
          }
        });
        return nullptr;
      },
      // onCancel
      [this, stop](const EncodableVal* /*args*/)
          -> std::unique_ptr<flutter::StreamHandlerError<EncodableVal>> {
        *stop = true;
        if (battery_thread_.joinable()) battery_thread_.join();
        return nullptr;
      });

  battery_channel_->SetStreamHandler(std::move(handler));
}

// =============================================================================
// 3. BasicMessageChannel — StandardMessageCodec
// =============================================================================
// Windows only provides StandardMessageCodec for BasicMessageChannel.
// The Dart side must also use const StandardMessageCodec() to match.
// Channel: "com.example.nativechannels/win_message"

void ChannelManager::SetupMessageChannel(
    flutter::BinaryMessenger* messenger) {
  message_channel_ =
      std::make_unique<flutter::BasicMessageChannel<EncodableVal>>(
          messenger,
          "com.example.nativechannels/win_message",
          &flutter::StandardMessageCodec::GetInstance());

  message_channel_->SetMessageHandler(
      [](const EncodableVal& message,
         flutter::MessageReply<EncodableVal> reply) {

        if (const auto* text = std::get_if<std::string>(&message)) {
          reply(EncodableVal("Windows echoes: " + *text));

        } else if (const auto* map = std::get_if<EncodableMap>(&message)) {
          std::string action = GetString(*map, "action");
          if (action == "getConfig") {
            reply(EncodableVal(EncodableMap{
                {EncodableVal("platform"), EncodableVal(std::string("windows"))},
                {EncodableVal("theme"),    EncodableVal(std::string("dark"))},
                {EncodableVal("version"),  EncodableVal(std::string("2.0"))},
                {EncodableVal("debug"),    EncodableVal(false)},
            }));
          } else {
            reply(EncodableVal(EncodableMap{
                {EncodableVal("error"),
                 EncodableVal(std::string("unknown action"))},
            }));
          }
        } else {
          reply(EncodableVal());
        }
      });

  // Native-initiated message to Dart after 3 seconds.
  std::thread([this]() {
    std::this_thread::sleep_for(std::chrono::seconds(3));
    message_channel_->Send(
        EncodableVal(std::string("Hello from Windows! (native-initiated)")),
        nullptr);
  }).detach();
}

// =============================================================================
// Entry point
// =============================================================================

std::unique_ptr<ChannelManager> SetupChannels(
    flutter::BinaryMessenger* messenger) {
  return std::make_unique<ChannelManager>(messenger);
}
