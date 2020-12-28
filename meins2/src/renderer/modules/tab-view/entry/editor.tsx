import React, {
  Dispatch,
  KeyboardEvent,
  SetStateAction,
  useCallback,
  useMemo,
  useRef,
  useState,
} from 'react'
import Editor from '@draft-js-plugins/editor'
import createMentionPlugin, {
  defaultSuggestionsFilter,
  MentionData,
} from '@draft-js-plugins/mention'
import createLinkifyPlugin from '@draft-js-plugins/linkify'
import {
  convertToRaw,
  convertFromRaw,
  EditorState,
  getDefaultKeyBinding,
  KeyBindingUtil,
  DraftHandleValue,
  RichUtils,
  DraftEditorCommand,
} from 'draft-js'
import { mdToDraftjs, draftjsToMd } from 'draftjs-md-converter'
import 'draft-js/dist/Draft.css'
import { Entry } from '../../../../generated/graphql'
import '@draft-js-plugins/mention/lib/plugin.css'

const { hasCommandModifier } = KeyBindingUtil

const mentions = [
  {
    name: '#meh',
  },
  {
    name: '#awesome',
  },
  {
    name: '#nice',
  },
] as MentionData[]

function logMarkdown(editorState: EditorState) {
  const content = editorState.getCurrentContent()
  const md = draftjsToMd(convertToRaw(content))
  const text = content.getPlainText()
  console.log(md)
  console.log(text)
}

export function EditMenu({
  editorState,
  setEditorState,
}: {
  editorState: EditorState
  setEditorState: Dispatch<SetStateAction<EditorState>>
}) {
  function toggleInlineStyle(inlineStyle: string) {
    setEditorState(RichUtils.toggleInlineStyle(editorState, inlineStyle))
  }

  function toggleBlockType(blockType: string) {
    setEditorState(RichUtils.toggleBlockType(editorState, blockType))
  }

  return (
    <div className="RichEditor-controls edit-menu">
      <i
        className="fa far fa-save fa-wide"
        onClick={() => logMarkdown(editorState)}
      />
      <i
        className="fa far fa-bold fa-wide"
        onClick={() => toggleInlineStyle('BOLD')}
      />
      <i
        className="fa far fa-italic fa-wide"
        onClick={() => toggleInlineStyle('ITALIC')}
      />
      <i
        className="fa far fa-underline fa-wide"
        onClick={() => toggleInlineStyle('UNDERLINE')}
      />
      <i
        className="fa far fa-code fa-wide"
        onClick={() => toggleInlineStyle('CODE')}
      />
      <i
        className="fa far fa-strikethrough fa-wide"
        onClick={() => toggleInlineStyle('STRIKETHROUGH')}
      />
      <i
        className="fa far fa-heading"
        onClick={() => toggleBlockType('header-one')}
      />
      <i
        className="fa far fa-heading header-2"
        onClick={() => toggleBlockType('header-two')}
      />
      <i
        className="fa far fa-heading header-3"
        onClick={() => toggleBlockType('header-three')}
      />
      <i
        className="fa far fa-list-ul fa-wide active-button"
        onClick={() => toggleBlockType('unordered-list-item')}
      />
      <i
        className="fa far fa-list-ol fa-wide"
        onClick={() => toggleBlockType('ordered-list-item')}
      />
    </div>
  )
}

export function EditorView({ item }: { item: Entry }) {
  const [editorState, setEditorState] = useState(() =>
    EditorState.createWithContent(
      convertFromRaw(mdToDraftjs(item.md || item.text || '')),
    ),
  )
  const [suggestions, setSuggestions] = useState(mentions)
  const [open, setOpen] = useState(true)

  const { HashtagSuggestions, plugins } = useMemo(() => {
    const linkifyPlugin = createLinkifyPlugin()
    const hashtagPlugin = createMentionPlugin({ mentionTrigger: '#' })
    const { MentionSuggestions } = hashtagPlugin
    const plugins = [hashtagPlugin, linkifyPlugin]
    return { plugins, HashtagSuggestions: MentionSuggestions }
  }, [])

  function keyBindingFn(e: KeyboardEvent): DraftEditorCommand {
    if (e.keyCode === 83 /* `S` key */ && hasCommandModifier(e)) {
      //return 'editor-save'
    }
    return getDefaultKeyBinding(e)
  }

  function handleKeyCommand(command: string): DraftHandleValue {
    const newState = RichUtils.handleKeyCommand(editorState, command)

    if (newState) {
      setEditorState(newState)
      return 'handled'
    }

    if (command === 'editor-save') {
      logMarkdown(editorState)
      return 'handled'
    }
    return 'not-handled'
  }

  function onSearchChange({ value }: { value: string }) {
    console.log(value)
    setSuggestions(defaultSuggestionsFilter(value, mentions))
  }

  const onOpenChange = useCallback((_open: boolean) => {
    setOpen(_open)
  }, [])

  return (
    <div className="entry-text">
      <EditMenu editorState={editorState} setEditorState={setEditorState} />
      <Editor
        editorState={editorState}
        onChange={setEditorState}
        placeholder=""
        keyBindingFn={keyBindingFn}
        handleKeyCommand={handleKeyCommand}
        plugins={plugins}
      />
      <HashtagSuggestions
        onSearchChange={onSearchChange}
        suggestions={suggestions}
        onOpenChange={onOpenChange}
        open={open}
      />
    </div>
  )
}
