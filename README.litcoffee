
![PlayFrame](https://avatars3.githubusercontent.com/u/47147479)
# ShaDOM

###### 1.5 kB DOM + Shadow DOM Manipulation

## Installation
```sh
npm install --save @playframe/shadom
```

## Usage
```js
import oversync from '@playframe/oversync'
import h from '@playframe/h'
import shadom from '@playframe/shadom'

const sync = oversync(Date.now, requestAnimationFrame)

const state = {}
const View = (state)=> <div></div> // h('div')

const render = shadom(sync)(document.body)

// to update DOM we do
render(View, state)
```

## Annotated Source

`@playframe/h` is required as peer dependency. We are importing
a `VNODE`
[Symbol](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Symbol)
constant. Symbol can't be created twice in two different places.
It is important to use the same instance of `@playframe/h` acroass
your app

    {VNODE} = h = require '@playframe/h'


    {isArray} = Array
    doc = document

Let's remind outselves our virtual dom data structure
`['div', {class: 's'}, children...]` to clarify the constants.

    NAME = 0
    ATTR = 1
    FIRST_CHILD = 2

Symbols are designed to assign metaproperties to existing
objects. Those properties are not occuring in `for` or `Object.keys`
iteration. They are also free from name conflicts. For example
different libraries can create own `Symbol('ELEMENT')` and use them
on the same object without any collision

    ELEMENT = Symbol 'ELEMENT'
    EVENTS = Symbol 'EVENTS'
    KEYED = Symbol 'KEYED'


    _sync = null
    _first_run = true

This function will schedule actual event handling at
the begging of the next work batch

    eventHandler = (event)=>
      f = event.currentTarget[EVENTS][event.type]
      _sync.next => f event
      return


We are exporting a higher order function that will take `sync` scheduler
and a `root` element. It will return a function that takes latest
`view` function and `state` and schedules vDOM producing and
DOM mutating

    module.exports = (sync)=>(root)=>
      _sync = sync

      _v_dom = null
      _new_v_dom = null
      if _dom = root.children[0]
        _v_dom = scan _dom

      render = =>
        _dom = mutate_dom root, _dom, _new_v_dom, _v_dom
        _v_dom = _new_v_dom
        return

      (view, state)=>
        _new_v_dom = view state
        
        if _first_run # render asap
          do render
          _first_run = false
        else
          _sync.render render

        return

Reusing preexisting html nodes in `root` element. This will benefit
apps with server side pre-rendering

    scan = (el, NS)=>
      NS = el.namespaceURI or NS
      if el.nodeType is 3 # text
        el.nodeValue
      else
        v_dom = h el.nodeName.toLowerCase(), null
        {childNodes} = if shadow = el.shadowRoot
          v_dom.patch = patcher v_dom, el, shadow, NS
          shadow
        else
          el
        for i in [0...childNodes.length] by 1
          v_dom.push scan childNodes[i]
        v_dom

This function will take a DOM element `el` and its `parent` element.
Also it takes a new vDOM `vnode` and `old_vnode`. Their diff will
mutate `el`. `NS` is a XMLNS namespace for working with SVG or XHTML

    mutate_dom = (parent, el, vnode, old_vnode, NS)=>
      # console.log 'mutate_dom', vnode, old_vnode
      unless vnode is old_vnode
        if old_vnode? and vnode? and not old_vnode[VNODE] and not vnode[VNODE]
          el.nodeValue = vnode # text node
        else
          # for SVG or XHTML
          NS = vnode and vnode[ATTR]?.xmlns or NS

          if not vnode? or not old_vnode? or old_vnode[NAME] isnt vnode[NAME]
            # replace node
            if vnode?
              new_el = make_el vnode, NS
              parent.insertBefore new_el, el
            if old_vnode?
              remove_el parent, el
              _sync.next => emmit_remove old_vnode
            return new_el

          else # update node

            if patch = old_vnode.patch
              vnode.patch = patch
              patch vnode
            else
              set_attr el, vnode[ATTR], old_vnode[ATTR], NS
              mutate_children el, vnode, old_vnode, NS

            if onupdate = vnode[ATTR] and vnode[ATTR][if _first_run
                'oncreate'
              else 'onupdate'
            ]
              onupdate el
      el

This function will compare and mutate children of given `el`.
Keyed updates are supported

    mutate_children = (el, vnode, old_vnode, NS)=>
      i = j = FIRST_CHILD
      sub_i = sub_j = sub_il = sub_jl = el_i = 0
      l = vnode.length
      ll = old_vnode?.length or 0
      by_key = false


      while true
      # 2 inline child walkers for performance reasons
      # getting next child in ['div', {}, child, [child, child],...]
        while i <= l
          child = vnode[i]
          if not child? or child in [true, false]
            i++ # continue
          else if child[VNODE] or not isArray child
            i++
            break
          else
            sub_il or= child.length
            if (sub_child = child[sub_i])? and sub_child not in [true, false]
              sub_i++
              child = sub_child
              break
            else
              if sub_i < sub_il
                sub_i++
              else
                sub_i = sub_il = 0
                i++

        key = get_key child


        while j <= ll
          old_key = null
          old_child = old_vnode[j]
          if not old_child? or old_child in [true, false]
            j++ # continue
          else if old_child[VNODE] or not isArray old_child
            j++
            old_key = get_key old_child
            break unless old_keyed and old_key and not old_keyed[old_key]
          else
            sub_jl or= old_child.length
            if (sub_child = old_child[sub_j])? and sub_child not in [true, false]
              sub_j++
              old_child = sub_child
              old_key = get_key old_child
              break unless old_keyed and old_key and not old_keyed[old_key]
            else
              if sub_j < sub_jl
                sub_j++
              else
                sub_j = sub_jl = 0
                j++

        break unless child? or old_child?

        child_el = el.childNodes[el_i]


        if not by_key and (key or old_key)
          by_key = true # switch to keyed mode
          old_keyed = old_vnode and old_vnode[KEYED]
          keyed = vnode[KEYED] = Object.create null


        unless old_keyed and child and old_key isnt key
          # direct mutation unless key mismatch
          child_el = mutate_dom el, child_el, child, old_child, NS

        else
          # if there is key mismatch
          # we will replace current dom node
          # with an existing keyed or a new one
          if replacement = old_keyed[key]
            replaced_el = mutate_dom el, replacement[ELEMENT], child, replacement, NS
          else
            replaced_el = make_el child, NS

          el.insertBefore replaced_el, child_el

          if old_child
            remove_el el, child_el
            if old_key
              # emit remove if not reused
              _sync.render do (old_key)=>=> # old_key closure
                if old_keyed[old_key]
                  emmit_remove old_keyed[old_key]
            else
              emmit_remove old_child

          child_el = replaced_el


        if child?
          el_i++ # moving pointer to next DOM element
          if key
            child[ELEMENT] = child_el
            keyed[key] = child
            old_keyed and old_keyed[key] = null

      # end of loop

      if old_keyed
        # copying over unused cached keyed nodes
        for k, v of old_keyed when v
          keyed[k] = v

      return

This function will create a new DOM element with its children

    make_el = (vnode, NS)=>
      if vnode[VNODE]
        el = if NS
          doc.createElementNS NS, vnode[NAME]
        else
          doc.createElement vnode[NAME]

        set_attr el, vnode[ATTR], null, NS

        if shadow_props = vnode[ATTR] and vnode[ATTR].attachShadow
          shadow = el.attachShadow shadow_props
          vnode.patch = patcher vnode, el, shadow, NS
          mutate_children shadow, vnode, null, NS
        else
          mutate_children el, vnode, null, NS

        if oncreate = vnode[ATTR] and vnode[ATTR].oncreate
          oncreate el

        el
      else
        doc.createTextNode vnode

Removing element from its parent

    remove_el = (parent, el)=>
      parent.removeChild el
      return


    emmit_remove = (vnode)=>
      {length} = vnode

      while length-- > 0
        if isArray child = vnode[length]
          emmit_remove child

      if onremove = vnode[ATTR] and vnode[ATTR].onremove
        onremove()
      return

Comparing and setting attributes

    set_attr = (el, attr, old_attr, NS)=>
      for k, old_v of old_attr when not (attr and attr[k]?)
        set el, k, null, old_v, NS

      for k, v of attr
        old_v = if k in ['value', 'checked']
          el[k]
        else
          old_attr and old_attr[k]

        set el, k, v, old_v, NS if v isnt old_v

      return



    set = (el, name, value, old_value, NS)=>
      if name in ['key', 'attachShadow']
        # skip
      else if name is 'style'
        style = el[name]
        if typeof value is 'string'
          style.cssText = value
        else
          if typeof old_value is 'string'
            style.cssText = ''
          else
            value = {value...}
            for k of old_value
              value[k] ?= ''

          for k, v of value
            if k.charCodeAt(0) is 45 # starts with '-'
              style.setProperty k, v
            else
              style[k] = v

      else
        # starts with 'on', event listener
        if name.charCodeAt(0) is 111 and name.charCodeAt(1) is 110
          name = name.slice 2
          events = el[EVENTS] or= {}
          old_value or= events[name]
          events[name] = value

          if value
            if !old_value
              el.addEventListener name, eventHandler
          else
            el.removeEventListener name, eventHandler

        # attribute
        else if (name of el and
            name not in ['list', 'type', 'draggable', 'spellcheck', 'translate'] and
            not NS)
          el[name] = value ?= ''

        else if value? and value isnt false
          el.setAttribute name, value
        else
          el.removeAttribute name

      return

Getting a key from a virtual node

    get_key = (vnode)=> vnode and vnode[ATTR] and vnode[ATTR].key

Creating a shadow DOM `patch` function 

    patcher = (_old_vnode, el, shadow, NS)=>(vnode)=>
      unless vnode is _old_vnode
        set_attr el, vnode[ATTR], _old_vnode[ATTR], NS
        mutate_children shadow, vnode, _old_vnode, NS
        _old_vnode = vnode
      return
