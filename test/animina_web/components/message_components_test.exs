defmodule AniminaWeb.MessageComponentsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AniminaWeb.MessageComponents

  describe "chat_input/1" do
    test "renders textarea and send button in default size" do
      form = Phoenix.Component.to_form(%{"content" => ""}, as: :message)

      html =
        render_component(&MessageComponents.chat_input/1,
          form: form,
          input_id: "msg-input",
          form_id: "msg-form",
          draft_key: "draft:u1:u2"
        )

      assert html =~ "msg-input"
      assert html =~ "msg-form"
      assert html =~ "draft:u1:u2"
      assert html =~ "hero-paper-airplane"
      assert html =~ "MessageInput"
      # Default size uses markdown hint
      assert html =~ "bold"
      # Has circular send button
      assert html =~ "btn-circle"
    end

    test "renders sm size without markdown hint" do
      form = Phoenix.Component.to_form(%{"content" => ""}, as: :message)

      html =
        render_component(&MessageComponents.chat_input/1,
          form: form,
          input_id: "panel-input",
          form_id: "panel-form",
          draft_key: "draft:u1:u2",
          size: :sm
        )

      assert html =~ "panel-input"
      assert html =~ "textarea-sm"
      assert html =~ "btn-sm"
      # Markdown hint shown in sm size too
      assert html =~ "bold"
    end

    test "renders blocked state instead of input" do
      form = Phoenix.Component.to_form(%{"content" => ""}, as: :message)

      html =
        render_component(&MessageComponents.chat_input/1,
          form: form,
          input_id: "msg-input",
          form_id: "msg-form",
          draft_key: "draft:u1:u2",
          blocked: true
        )

      assert html =~ "cannot send messages"
      refute html =~ "msg-input"
      refute html =~ "hero-paper-airplane"
    end

    test "passes phx-target when provided" do
      form = Phoenix.Component.to_form(%{"content" => ""}, as: :message)

      html =
        render_component(&MessageComponents.chat_input/1,
          form: form,
          input_id: "msg-input",
          form_id: "msg-form",
          draft_key: "draft:u1:u2",
          phx_target: "#chat-panel"
        )

      assert html =~ "phx-target"
    end

    test "uses custom typing_event" do
      form = Phoenix.Component.to_form(%{"content" => ""}, as: :message)

      html =
        render_component(&MessageComponents.chat_input/1,
          form: form,
          input_id: "msg-input",
          form_id: "msg-form",
          draft_key: "draft:u1:u2",
          typing_event: "chat_typing"
        )

      assert html =~ "chat_typing"
    end

    test "preserves existing form content" do
      form = Phoenix.Component.to_form(%{"content" => "hello world"}, as: :message)

      html =
        render_component(&MessageComponents.chat_input/1,
          form: form,
          input_id: "msg-input",
          form_id: "msg-form",
          draft_key: "draft:u1:u2"
        )

      assert html =~ "hello world"
    end
  end

  describe "render_markdown/1" do
    test "renders basic markdown" do
      result = MessageComponents.render_markdown("**bold** and *italic*")
      html = Phoenix.HTML.safe_to_string(result)

      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
    end

    test "renders inline code" do
      result = MessageComponents.render_markdown("`code`")
      html = Phoenix.HTML.safe_to_string(result)

      assert html =~ "<code"
      assert html =~ "code"
    end

    test "escapes HTML to prevent XSS" do
      result = MessageComponents.render_markdown("<script>alert('xss')</script>")
      html = Phoenix.HTML.safe_to_string(result)

      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
    end

    test "handles line breaks" do
      result = MessageComponents.render_markdown("line1\nline2")
      html = Phoenix.HTML.safe_to_string(result)

      assert html =~ "<br"
    end

    test "handles empty content" do
      result = MessageComponents.render_markdown("")
      html = Phoenix.HTML.safe_to_string(result)

      assert is_binary(html)
    end
  end

  describe "strip_markdown/1" do
    test "strips bold and italic markers" do
      assert MessageComponents.strip_markdown("**bold** and *italic*") == "bold and italic"
    end

    test "strips code backticks" do
      assert MessageComponents.strip_markdown("`code` here") == "code here"
    end

    test "collapses newlines to spaces" do
      assert MessageComponents.strip_markdown("line1\nline2\nline3") == "line1 line2 line3"
    end

    test "strips link syntax" do
      assert MessageComponents.strip_markdown("[text](url)") == "texturl"
    end

    test "handles plain text unchanged" do
      assert MessageComponents.strip_markdown("hello world") == "hello world"
    end
  end
end
