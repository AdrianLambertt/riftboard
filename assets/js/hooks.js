import Sortable from "sortablejs"

const Hooks = {
  Sortable: {
    mounted() {
      new Sortable(this.el, {
        group: "cards",
        animation: 150,
        ghostClass: "ring-2",
        dragClass: "opacity-50",
        onEnd: (evt) => {
          // Only push if position or column actually changed
          if (evt.oldIndex === evt.newIndex && evt.from === evt.to) return

          this.pushEvent("card_moved", {
            card_id: evt.item.dataset.cardId,
            column_id: evt.to.dataset.columnId,
            position: evt.newIndex
          })
        }
      })
    }
  }
}

export default Hooks
